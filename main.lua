--// Pawfy Project - Main Monitor (Fixed Status & Symbols)
--// Link: https://raw.githubusercontent.com/pawfyproject-hub/pawfy/refs/heads/main/main.lua

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or (syn and syn.request) or request

-- CONFIG & STATE
local CONFIG_FILE = "pawfy-config.json"
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local INTERVAL = 50 

local webhook
local messageId
local startTime = os.time()

-- 1. LOAD CONFIG
if isfile(CONFIG_FILE) then
    local s, cfg = pcall(HttpService.JSONDecode, HttpService, readfile(CONFIG_FILE))
    if s and cfg.webhook then webhook = cfg.webhook end
end

-- 2. GUI INPUT (Hanya jika belum ada config)
if not webhook then
    local gui = Instance.new("ScreenGui", game.CoreGui)
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.3, 0.2)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    
    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.8, 0.3)
    box.Position = UDim2.fromScale(0.1, 0.2)
    box.PlaceholderText = "Paste Webhook URL"
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.3)
    btn.Position = UDim2.fromScale(0.3, 0.6)
    btn.Text = "SAVE"
    
    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord") then
            webhook = box.Text
            writefile(CONFIG_FILE, HttpService:JSONEncode({webhook = webhook}))
            gui:Destroy()
        end
    end)
    repeat task.wait() until webhook
end

-- 3. PAYLOAD FUNCTION (Symbol on Status Line)
local function getPayload(is_offline)
    local uptime_s = os.time() - startTime
    local ping = "N/A"
    pcall(function()
        ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
    end)

    return HttpService:JSONEncode({
        username = WEBHOOK_NAME,
        avatar_url = AVATAR_URL,
        embeds = {{
            title = "🖥️ " .. BOT_NAME .. " MONITOR",
            color = is_offline and 16711680 or 65535,
            fields = {
                { name = "User", value = "||"..LocalPlayer.Name.."||", inline = true },
                { name = "Status", value = is_offline and "**🔴 INACTIVE**" or "**🟢 ACTIVE**", inline = true },
                { name = "Uptime", value = string.format("%02d:%02d:%02d", uptime_s//3600, (uptime_s%3600)//60, uptime_s%60), inline = true },
                { name = "Memory", value = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), inline = true },
                { name = "Ping", value = ping, inline = true }
            },
            footer = { text = "Pawfy Project • Real-time Updates" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
end

-- 4. UPDATE LOGIC (Original Pawfy Logic)
local function updateStatus(is_offline)
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local success, res = pcall(function()
        return request({
            Url = url,
            Method = method,
            Headers = {["Content-Type"] = "application/json"},
            Body = getPayload(is_offline)
        })
    end)

    if success and res and res.Body and not messageId then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok and data and data.id then messageId = data.id end
    end
end

-- 5. HEARTBEAT LOOP (Looping 50s)
task.spawn(function()
    updateStatus(false) -- First Send
    while task.wait(INTERVAL) do
        -- Anti-AFK
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
        
        -- Update Message
        pcall(function()
            updateStatus(false)
        end)
    end
end)

-- Offline status saat game tutup
game:BindToClose(function()
    updateStatus(true)
    task.wait(1)
end)
