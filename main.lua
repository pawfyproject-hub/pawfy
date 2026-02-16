--// Pawfy Sys - Final Update (Optimize + Notifier Only)
--// Author: Pawfy Project

-- SERVICES
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or (syn and syn.request) or request

-- ==========================================================
-- 1. PAWFY OPTIMIZE (Instan hemat CPU/RAM)
-- ==========================================================
pcall(function()
    if setfpscap then setfpscap(15) end
    RunService:Set3dRenderingEnabled(false) -- Sangat krusial untuk Cloudphone
    settings().Rendering.QualityLevel = 1
    Lighting.GlobalShadows = false
    
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") then
            v.Enabled = false
        end
    end
end)

-- CONFIG & STATE
local CONFIG_FILE = "pawfy-config.json"
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local INTERVAL = 50 

local webhook
local messageId
local startTime = os.time()

-- ==========================================================
-- 2. AUTO-LOAD CONFIG (Biar tidak minta input terus)
-- ==========================================================
local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local s, d = pcall(HttpService.JSONDecode, HttpService, readfile(CONFIG_FILE))
        return s and d or nil
    end
end

local function saveConfig(data)
    if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end
end

local cfg = loadConfig()
if cfg and cfg.webhook then webhook = cfg.webhook end

-- GUI INPUT (Hanya jika link kosong)
if not webhook then
    local gui = Instance.new("ScreenGui", game.CoreGui)
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.35, 0.2)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Instance.new("UICorner", frame)

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.8, 0.3)
    box.Position = UDim2.fromScale(0.1, 0.2)
    box.PlaceholderText = "Paste Webhook URL"
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    box.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", box)
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.3)
    btn.Position = UDim2.fromScale(0.3, 0.6)
    btn.Text = "SAVE"
    btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    btn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", btn)
    
    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord") then
            webhook = box.Text
            saveConfig({webhook = webhook})
            gui:Destroy()
        end
    end)
    repeat task.wait() until webhook
end

-- ==========================================================
-- 3. WEBHOOK LOGIC (Symbol & Real-time Update)
-- ==========================================================
local function getPayload(is_offline)
    local status_display = is_offline and "🔴 INACTIVE" or "🟢 ACTIVE"
    local color = is_offline and 16711680 or 65535
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
            color = color,
            fields = {
                { name = "User", value = "||"..LocalPlayer.Name.."||", inline = true },
                { name = "Status", value = "**" .. status_display .. "**", inline = true },
                { name = "Uptime", value = string.format("%02d:%02d:%02d", uptime_s//3600, (uptime_s%3600)//60, uptime_s%60), inline = true },
                { name = "Memory", value = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), inline = true },
                { name = "Ping", value = ping, inline = true }
            },
            footer = { text = "Pawfy Project • Stable Version" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
end

local function updateWebhook(is_offline)
    if not webhook then return end
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local success, res = pcall(function()
        return request({
            Url = url,
            Method = method,
            Headers = {["Content-Type"]="application/json"},
            Body = getPayload(is_offline)
        })
    end)
    
    if success and res and res.Body and not messageId then
        local s, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if s and data and data.id then messageId = data.id end
    end
end

-- ==========================================================
-- 4. STABLE LOOPING (Looping Update 50 Detik)
-- ==========================================================
task.spawn(function()
    updateWebhook(false) -- Kirim pertama kali
    
    while task.wait(INTERVAL) do
        -- Anti-AFK
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
        
        -- RAM Cleanup & Edit Status
        if collectgarbage then collectgarbage("collect") end
        pcall(function() updateWebhook(false) end)
    end
end)

game:BindToClose(function()
    updateWebhook(true)
    task.wait(1.2)
end)
