--// Pawfy Sys - Fixed Auto-Update Monitor
--// Author: Pawfy Project

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or (syn and syn.request) or request

-- ==========================================================
-- 1. OPTIMIZE (Langsung Eksekusi)
-- ==========================================================
pcall(function()
    if setfpscap then setfpscap(15) end
    RunService:Set3dRenderingEnabled(false)
    settings().Rendering.QualityLevel = 1
    Lighting.GlobalShadows = false
end)

-- CONFIG & STATE
local CONFIG_FILE = "pawfy-config.json"
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local INTERVAL = 50 

local webhook
local messageId = nil -- Akan diisi otomatis
local startTime = os.time()

-- ==========================================================
-- 2. CONFIG LOADER
-- ==========================================================
if isfile and isfile(CONFIG_FILE) then
    local s, d = pcall(HttpService.JSONDecode, HttpService, readfile(CONFIG_FILE))
    if s and d.webhook then webhook = d.webhook end
end

if not webhook then
    -- GUI Sederhana Jika Webhook Kosong
    local gui = Instance.new("ScreenGui", game.CoreGui)
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.3, 0.15)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    
    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.9, 0.4)
    box.Position = UDim2.fromScale(0.05, 0.1)
    box.PlaceholderText = "Paste Webhook"
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.3)
    btn.Position = UDim2.fromScale(0.3, 0.6)
    btn.Text = "SAVE"
    
    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord") then
            webhook = box.Text
            if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode({webhook = webhook})) end
            gui:Destroy()
        end
    end)
    repeat task.wait() until webhook
end

-- ==========================================================
-- 3. PAYLOAD & UPDATE LOGIC (FIXED)
-- ==========================================================
local function getStatusData(is_offline)
    local uptime_s = os.time() - startTime
    local ping = "N/A"
    pcall(function()
        ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
    end)

    return {
        ["username"] = WEBHOOK_NAME,
        ["avatar_url"] = AVATAR_URL,
        ["embeds"] = {{
            ["title"] = "🖥️ " .. BOT_NAME .. " MONITOR",
            ["color"] = is_offline and 16711680 or 65535,
            ["fields"] = {
                {["name"] = "User", ["value"] = "||"..LocalPlayer.Name.."||", ["inline"] = true},
                {["name"] = "Status", ["value"] = is_offline and "**🔴 INACTIVE**" or "**🟢 ACTIVE**", ["inline"] = true},
                {["name"] = "Uptime", ["value"] = string.format("%02d:%02d:%02d", uptime_s//3600, (uptime_s%3600)//60, uptime_s%60), ["inline"] = true},
                {["name"] = "Memory", ["value"] = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), ["inline"] = true},
                {["name"] = "Ping", ["value"] = ping, ["inline"] = true}
            },
            ["footer"] = {["text"] = "Pawfy Project • Final Fixed Update"},
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
end

local function sendWebhookUpdate(is_offline)
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local success, response = pcall(function()
        return request({
            Url = url,
            Method = method,
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(getStatusData(is_offline))
        })
    end)

    -- KRUSIAL: Menangkap Message ID dari response POST pertama
    if success and response and not messageId then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and data and data.id then
            messageId = data.id
        end
    end
end

-- ==========================================================
-- 4. THE CORE LOOP (ANTI-STOP)
-- ==========================================================
task.spawn(function()
    -- Kirim status awal
    sendWebhookUpdate(false)
    
    while true do
        task.wait(INTERVAL)
        
        -- Anti-AFK
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)

        -- Memory Cleanup
        if collectgarbage then collectgarbage("collect") end

        -- Force Update
        local ok, err = pcall(function()
            sendWebhookUpdate(false)
        end)
        
        if not ok then
            print("Pawfy Sys Update Error: " .. tostring(err))
            -- Jika error karena messageId rusak, reset agar kirim pesan baru
            if tostring(err):find("404") then messageId = nil end 
        end
    end
end)

-- Offline status saat ditutup
game:BindToClose(function()
    sendWebhookUpdate(true)
    task.wait(1)
end)
