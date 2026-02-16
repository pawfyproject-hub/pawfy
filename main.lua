--// Pawfy Sys - Optimized for Cloudphone
--// Author: Pawfy (YourPaw)

-- SERVICES
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or request

-- =========================
-- 0. INSTANT OPTIMIZATION (CPU/RAM)
-- =========================
if setfpscap then setfpscap(15) end
RunService:Set3dRenderingEnabled(false)

settings().Rendering.QualityLevel = 1
Lighting.GlobalShadows = false
for _, v in pairs(Lighting:GetChildren()) do
    if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") then
        v.Enabled = false
    end
end

-- FILES
local CONFIG_FILE = "pawfy-sys-config.json"
local SESSION_FILE = "pawfy-sys-session.json"

-- CONSTANTS
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local INTERVAL = 60 

-- STATE
local webhook
local messageId
local startTime = os.time()
local lastTick = os.clock()

-- =========================
-- SESSION & CONFIG
-- =========================
local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end
end

local function saveConfig(data)
    writefile(CONFIG_FILE, HttpService:JSONEncode(data))
end

local cfg = loadConfig()
if cfg and cfg.webhook then
    webhook = cfg.webhook
end

-- =========================
-- GUI INPUT WEBHOOK
-- =========================
if not webhook then
    local gui = Instance.new("ScreenGui", game.CoreGui)
    gui.Name = "PawfySysGui"
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.45, 0.3)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 20)

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.9, 0.25)
    box.Position = UDim2.fromScale(0.05, 0.4)
    box.PlaceholderText = "Paste Discord Webhook URL"
    box.BackgroundColor3 = Color3.fromRGB(30,30,30)
    box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.Gotham
    box.TextSize = 16
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.2)
    btn.Position = UDim2.fromScale(0.3, 0.7)
    btn.Text = "SAVE & START"
    btn.BackgroundColor3 = Color3.fromRGB(0,200,255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)

    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord.com/api/webhooks") then
            webhook = box.Text
            saveConfig({ webhook = webhook })
            gui:Destroy()
        end
    end)
    repeat task.wait() until webhook
end

-- =========================
-- STATS & PAYLOAD
-- =========================
local function uptime()
    local s = os.time() - startTime
    return string.format("%02d:%02d:%02d", s//3600, (s%3600)//60, s%60)
end

local function payload(status_text)
    return {
        username = WEBHOOK_NAME,
        avatar_url = AVATAR_URL,
        embeds = {{
            title = "🖥️ " .. BOT_NAME .. " MONITOR",
            description = "Status: **" .. (status_text or "ACTIVE") .. "**",
            color = (status_text == "OFFLINE" and 0xFF0000 or 0x00E5FF),
            fields = {
                { name = "User", value = "||"..LocalPlayer.Name.."||", inline = true },
                { name = "Uptime", value = uptime(), inline = true },
                { name = "RAM Usage", value = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), inline = true },
                { name = "Mode", value = "Low Resource (15 FPS)", inline = true }
            },
            footer = { text = "Pawfy Project • Optimizer Active" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
end

local function send(is_closing)
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local r = request({
        Url = url,
        Method = method,
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(payload(is_closing and "OFFLINE"))
    })
    
    if r and r.Body and not messageId then
        local decoded = HttpService:JSONDecode(r.Body)
        messageId = decoded.id
    end
end

-- =========================
-- INIT & LOOPS
-- =========================
send() 

RunService.Heartbeat:Connect(function()
    if os.clock() - lastTick >= INTERVAL then
        lastTick = os.clock()
        if collectgarbage then collectgarbage("collect") end
        
        -- Anti-AFK
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
        
        pcall(function() send() end)
    end
end)

game:BindToClose(function()
    send(true)
    task.wait(2)
end)

-- =========================
-- LOAD MAIN SCRIPT
-- =========================
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/pawfyproject-hub/pawfy/refs/heads/main/main.lua"))()
    end)
end)
