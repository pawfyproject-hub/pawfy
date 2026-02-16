--// Pawfy Project - Multi Instance (Auto-Sync & PATCH)
--// Link: https://raw.githubusercontent.com/pawfyproject-hub/pawfy/refs/heads/main/main.lua

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or (syn and syn.request) or request

-- CONFIG & SHARED FILES
local WEBHOOK_FILE = "pawfy-webhook.json" 
local DATA_PATH = "pawfy-multi-instance.json" 
local MESSAGE_ID_FILE = "pawfy-message-id.txt" 
local INTERVAL = 50 

local webhook
local startTime = os.time()

-- 1. LOAD WEBHOOK
if isfile(WEBHOOK_FILE) then
    local s, cfg = pcall(HttpService.JSONDecode, HttpService, readfile(WEBHOOK_FILE))
    if s and cfg.webhook then webhook = cfg.webhook end
end

-- 2. LOGIKA AUTO-SYNC (Mencegah Data Hilang)
local function updateLocalData(is_offline)
    local allData = {}
    
    -- Baca data yang sudah ada milik akun lain
    if isfile(DATA_PATH) then
        local success, content = pcall(readfile, DATA_PATH)
        if success and content ~= "" then
            local s, decoded = pcall(HttpService.JSONDecode, HttpService, content)
            if s and type(decoded) == "table" then
                allData = decoded
            end
        end
    end

    -- Tambahkan/Update data akun ini ke dalam tabel gabungan
    if is_offline then
        allData[LocalPlayer.Name] = nil 
    else
        local cpu = "N/A"
        pcall(function() cpu = string.format("%.1fms", Stats.PerformanceStats.CPU:GetValue()) end)
        local ping = "N/A"
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. "ms" end)
        
        local uptime_s = os.time() - startTime
        allData[LocalPlayer.Name] = {
            status = "🟢",
            uptime = string.format("%02d:%02d", uptime_s//3600, (uptime_s%3600)//60),
            cpu = cpu,
            memValue = Stats:GetTotalMemoryUsageMb(),
            ping = ping,
            lastUpdate = os.time()
        }
    end
    
    -- Cleanup: Hapus akun yang tidak update > 2 menit
    for name, data in pairs(allData) do
        if os.time() - data.lastUpdate > 120 then allData[name] = nil end
    end

    -- Simpan kembali hasil penggabungan ke file shared
    writefile(DATA_PATH, HttpService:JSONEncode(allData))
    return allData
end

-- 3. SEND/PATCH WEBHOOK (Master Only)
local function sendGlobalEmbed(allData)
    local sortedNames = {}
    local totalRamUsed = 0
    for name, data in pairs(allData) do 
        table.insert(sortedNames, name) 
        totalRamUsed = totalRamUsed + (data.memValue or 0)
    end
    table.sort(sortedNames)
    
    -- Akun dengan nama alfabet pertama menjadi Master
    if sortedNames[1] ~= LocalPlayer.Name then return end

    local description = "👤 **User** | ⏳ **Up** | 🖥️ **CPU** | 🧠 **RAM** | 📡 **Ping**\n"
    description = description .. "--------------------------------------------------\n"
    for _, name in ipairs(sortedNames) do
        local d = allData[name]
        description = description .. string.format("%s `||%s||` | %s | %s | %.0fMB | %s\n", 
            d.status, name:sub(1,10), d.uptime, d.cpu, d.memValue, d.ping)
    end
    description = description .. "--------------------------------------------------\n"
    description = description .. string.format("📊 **Total RAM:** **%.2f GB**", totalRamUsed/1024)

    local payload = HttpService:JSONEncode({
        username = "Pawfy Multi-Monitor",
        embeds = {{
            title = "🖥️ PAWFY SYS MULTI-MONITOR",
            color = 65535,
            description = description,
            footer = { text = "Pawfy Project • " .. #sortedNames .. " Instances Active" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    })

    local msgId = isfile(MESSAGE_ID_FILE) and readfile(MESSAGE_ID_FILE) or nil
    local url = msgId and (webhook .. "/messages/" .. msgId) or (webhook .. "?wait=true")
    local method = msgId and "PATCH" or "POST"

    local success, res = pcall(function()
        return request({
            Url = url,
            Method = method,
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)

    -- Simpan Message ID baru jika POST pertama sukses
    if success and res and not msgId then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok and data and data.id then
            writefile(MESSAGE_ID_FILE, data.id)
        end
    elseif not success or (res and res.StatusCode == 404) then
        -- Reset jika pesan dihapus agar buat baru
        pcall(function() delfile(MESSAGE_ID_FILE) end)
    end
end

-- 4. HEARTBEAT LOOP
task.spawn(function()
    while true do
        local data = updateLocalData(false)
        sendGlobalEmbed(data)
        
        -- Anti-AFK
        pcall(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
        
        task.wait(INTERVAL)
    end
end)

game:BindToClose(function()
    updateLocalData(true)
end)
