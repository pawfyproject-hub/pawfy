--// Pawfy Sys - Clean Multi Instance Final (Fixed)
--// Author: Pawfy Project

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
-- 0. INSTANT OPTIMIZATION
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
local CONFIG_FILE = "pawfy-config.json"
local SESSION_FILE = "pawfy-session.json"

-- CONSTANTS
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local INTERVAL = 50 

-- STATE
local webhook
local messageId
local startTime = os.time()
local lastTick = os.clock()

-- =========================
-- CONFIG LOGIC
-- =========================
local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local content = readfile(CONFIG_FILE)
        local success, data = pcall(HttpService.JSONDecode, HttpService, content)
        return success and data or nil
    end
end

local function saveConfig(data)
    if writefile then 
        writefile(CONFIG_FILE, HttpService:JSONEncode(data)) 
    end
end

local cfg = loadConfig()
if cfg and cfg.webhook and cfg.webhook ~= "" then
    webhook = cfg.webhook
end

-- =========================
-- GUI INPUT
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
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.2)
    btn.Position = UDim2.fromScale(0.3, 0.7)
    btn.Text = "SAVE"
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
-- PAYLOAD (FIXED SYMBOL & STATUS)
-- =========================
local function payload(is_offline)
    local status_symbol = is_offline and "🔴" or "🟢"
    local status_text = is_offline and "INACTIVE" or "ACTIVE"
    local color = is_offline and 0xFF0000 or 0x00E5FF
    
    local uptime_s = os.time() - startTime
    local uptime_str = string.format("%02d:%02d:%02d", uptime_s//3600, (uptime_s%3600)//60, uptime_s%60)
    
    return {
        username = WEBHOOK_NAME,
        avatar_url = AVATAR_URL,
        embeds = {{
            title = status_symbol .. " " .. BOT_NAME .. " MONITOR",
            color = color,
            fields = {
                { name = "User", value = "||"..LocalPlayer.Name.."||", inline = true },
                { name = "Status", value = "**" .. status_text .. "**", inline = true },
                { name = "Uptime", value = uptime_str, inline = true },
                { name = "RAM", value = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), inline = true },
                { name = "Ping", value = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms", inline = true }
            },
            footer = { text = "Pawfy Project • Cloudphone System" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
end

-- =========================
-- WEBHOOK SEND / EDIT
-- =========================
local function send(is_offline)
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local success, r = pcall(function()
        return request({
            Url = url,
            Method = method,
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode(payload(is_offline))
        })
    end)
    
    -- Pastikan ID pesan disimpan untuk keperluan PATCH (Edit)
    if success and r and r.Body and not messageId then
        local data = HttpService:JSONDecode(r.Body)
        if data and data.id then
            messageId = data.id
        end
    end
end

-- =========================
-- MAIN LOOPS
-- =========================
send(false) -- Kirim status ACTIVE pertama kali

RunService.Heartbeat:Connect(function()
    if os.clock() - lastTick >= INTERVAL then
        lastTick = os.clock()
        
        -- Anti-AFK & Memory Cleanup
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
        if collectgarbage then collectgarbage("collect") end
        
        -- Jalankan Edit Status
        pcall(function() send(false) end)
    end
end)

game:BindToClose(function()
    send(true) -- Kirim status INACTIVE merah saat keluar
    task.wait(2)
end)

-- LOAD AUTOFARM
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/pawfyproject-hub/pawfy/refs/heads/main/main.lua"))()
    end)
end)
