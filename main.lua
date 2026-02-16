--// Pawfy Project - Professional Multi-Instance Monitor (Full Version)
--// Fitur: Auto-Sync, PATCH System, Total RAM, CPU Status, & GUI Setup

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

-- 1. LOAD WEBHOOK DARI FILE
if isfile(WEBHOOK_FILE) then
    local s, cfg = pcall(HttpService.JSONDecode, HttpService, readfile(WEBHOOK_FILE))
    if s and cfg.webhook and cfg.webhook ~= "" then 
        webhook = cfg.webhook 
    end
end

-- 2. GUI INPUT (Muncul hanya jika Webhook Kosong)
if not webhook or webhook == "" then
    local gui = Instance.new("ScreenGui", game.CoreGui)
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.35, 0.25)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.fromScale(1, 0.3)
    label.Text = "PAWFY SYS: SETUP WEBHOOK"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundTransparency = 1

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.9, 0.2)
    box.Position = UDim2.fromScale(0.05, 0.35)
    box.PlaceholderText = "Paste Discord Webhook Here"
    box.Text = ""

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.25)
    btn.Position = UDim2.fromScale(0.3, 0.65)
    btn.Text = "SAVE & START"
    btn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    btn.TextColor3 = Color3.new(1, 1, 1)

    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord") then
            webhook = box.Text
            writefile(WEBHOOK_FILE, HttpService:JSONEncode({webhook = webhook}))
            gui:Destroy()
        else
            box.PlaceholderText = "INVALID WEBHOOK URL!"
            box.Text = ""
        end
    end)
    repeat task.wait(1) until webhook -- Menahan script agar tidak lanjut tanpa webhook
end

-- 3. LOGIKA AUTO-SYNC DATA
local function updateLocalData(is_offline)
    local allData = {}
    if isfile(DATA_PATH) then
        local success, content = pcall(readfile, DATA_PATH)
        if success and content ~= "" then
            local s, decoded = pcall(HttpService.JSONDecode, HttpService, content)
            if s then allData = decoded end
        end
    end

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
    
    -- Cleanup akun tidak aktif (> 2 menit)
    for name, data in pairs(allData) do
        if os.time() - data.lastUpdate > 120 then allData[name] = nil end
    end

    writefile(DATA_PATH, HttpService:JSONEncode(allData))
    return allData
end

-- 4. SEND/PATCH EMBED (Master Only)
local function sendGlobalEmbed(allData)
    local sortedNames = {}
    local totalRamUsed = 0
    for name, data in pairs(allData) do 
        table.insert(sortedNames, name) 
        totalRamUsed = totalRamUsed + (data.memValue or 0)
    end
    table.sort(sortedNames)
    
    -- Urutan alfabet pertama menjadi Master pengirim webhook
    if sortedNames[1] ~= LocalPlayer.Name then return end

    local description = "👤 **User** | ⏳ **Up** | 🖥️ **CPU** | 🧠 **RAM** | 📡 **Ping**\n"
    description = description .. "--------------------------------------------------\n"
    for _, name in ipairs(sortedNames) do
        local d = allData[name]
        description = description .. string.format("%s `||%s||` | %s | %s | %.0fMB | %s\n", 
            d.status, name:sub(1,10), d.uptime, d.cpu, d.memValue, d.ping)
    end
    description = description .. "--------------------------------------------------\n"
    description = description .. string.format("📊 **Total RAM Usage:** **%.2f GB**", totalRamUsed/1024)

    local payload = HttpService:JSONEncode({
        username = "Pawfy Multi-Monitor",
        embeds = {{
            title = "🖥️ PAWFY SYS MULTI-MONITOR",
            color = 65535,
            description = description,
            footer = { text = "Pawfy Project • " .. #sortedNames .. " Accounts Active" },
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

    -- Simpan Message ID jika berhasil kirim POST pertama
    if success and res and not msgId then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok and data and data.id then
            writefile(MESSAGE_ID_FILE, data.id)
        end
    elseif not success or (res and res.StatusCode == 404) then
        pcall(function() delfile(MESSAGE_ID_FILE) end)
    end
end

-- 5. LOOPING UTAMA
task.spawn(function()
    while true do
        local data = updateLocalData(false)
        sendGlobalEmbed(data)
        
        -- Anti-AFK
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
        
        task.wait(INTERVAL)
    end
end)

-- Status saat offline
game:BindToClose(function()
    updateLocalData(true)
end)

print("Pawfy Sys: Multi-Instance Monitor Ready.")
