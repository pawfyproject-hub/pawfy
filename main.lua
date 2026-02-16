--// Pawfy Project - Professional Multi-Instance Monitor (Full & Fixed)
--// Fitur: Force GUI Setup, Auto-Sync, PATCH System, Total RAM & CPU Status

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

--// 1. FUNGSI LOAD/SAVE WEBHOOK (DIPERBAIKI)
local function loadWebhook()
    if isfile(WEBHOOK_FILE) then
        local success, content = pcall(readfile, WEBHOOK_FILE)
        if success then
            local s, cfg = pcall(HttpService.JSONDecode, HttpService, content)
            if s and cfg.webhook and cfg.webhook:find("discord") then
                return cfg.webhook
            end
        end
    end
    return nil
end

webhook = loadWebhook()

--// 2. FORCE GUI SETUP (Jika Webhook Kosong)
if not webhook or webhook == "" then
    if game.CoreGui:FindFirstChild("PawfySetup") then
        game.CoreGui.PawfySetup:Destroy()
    end

    local gui = Instance.new("ScreenGui", game.CoreGui)
    gui.Name = "PawfySetup"
    gui.DisplayOrder = 999
    
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.35, 0.25)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    
    -- Membuat sudut melengkung (UI Corner)
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.fromScale(1, 0.3)
    label.Text = "PAWFY SYS: WEBHOOK SETUP"
    label.TextColor3 = Color3.fromRGB(0, 255, 255)
    label.BackgroundTransparency = 1
    label.TextScaled = true

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.9, 0.25)
    box.Position = UDim2.fromScale(0.05, 0.35)
    box.PlaceholderText = "PASTE WEBHOOK DISINI"
    box.Text = ""
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.new(1, 1, 1)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.5, 0.2)
    btn.Position = UDim2.fromScale(0.25, 0.7)
    btn.Text = "SAVE WEBHOOK"
    btn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    btn.TextColor3 = Color3.new(1, 1, 1)

    btn.MouseButton1Click:Connect(function()
        local input = box.Text:gsub("%s+", "")
        if input:find("discord.com/api/webhooks") then
            webhook = input
            local data = HttpService:JSONEncode({webhook = webhook})
            local success, err = pcall(writefile, WEBHOOK_FILE, data)
            if success then
                gui:Destroy()
            else
                box.Text = ""
                box.PlaceholderText = "ERROR WRITING FILE!"
            end
        else
            box.Text = ""
            box.PlaceholderText = "LINK SALAH!"
        end
    end)
    repeat task.wait(0.5) until webhook and webhook ~= ""
end

--// 3. LOGIKA AUTO-SYNC (DATA SEMUA AKUN)
local function updateLocalData(is_offline)
    local allData = {}
    if isfile(DATA_PATH) then
        pcall(function()
            local content = readfile(DATA_PATH)
            allData = HttpService:JSONDecode(content)
        end)
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
    
    -- Hapus akun yang tidak update > 2 menit
    for name, data in pairs(allData) do
        if os.time() - data.lastUpdate > 120 then allData[name] = nil end
    end

    pcall(writefile, DATA_PATH, HttpService:JSONEncode(allData))
    return allData
end

--// 4. MASTER SEND/PATCH SYSTEM
local function sendGlobalEmbed(allData)
    local sortedNames = {}
    local totalRamUsed = 0
    for name, data in pairs(allData) do 
        table.insert(sortedNames, name) 
        totalRamUsed = totalRamUsed + (data.memValue or 0)
    end
    table.sort(sortedNames)
    
    -- Akun Master (Alphabet Pertama)
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

    if success and res and not msgId then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok and data and data.id then
            writefile(MESSAGE_ID_FILE, data.id)
        end
    elseif not success or (res and res.StatusCode == 404) then
        pcall(delfile, MESSAGE_ID_FILE)
    end
end

--// 5. HEARTBEAT LOOP
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

game:BindToClose(function()
    updateLocalData(true)
end)

print("Pawfy Sys: Professional Multi-Instance Loaded.")
