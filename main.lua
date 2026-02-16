--// Pawfy Sys - Final Verified Version
--// Author: Pawfy Project

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or request

-- OPTIMIZATION
if setfpscap then setfpscap(15) end
RunService:Set3dRenderingEnabled(false)
settings().Rendering.QualityLevel = 1
Lighting.GlobalShadows = false

-- CONFIG & STATE
local CONFIG_FILE = "pawfy-config.json"
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local INTERVAL = 50 
local webhook, messageId
local startTime = os.time()
local lastUpdate = os.time()

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local s, d = pcall(HttpService.JSONDecode, HttpService, readfile(CONFIG_FILE))
        return s and d or nil
    end
end

local cfg = loadConfig()
if cfg and cfg.webhook then webhook = cfg.webhook end

-- WEBHOOK PAYLOAD
local function getPayload(is_offline)
    local status_display = is_offline and "🔴 INACTIVE" or "🟢 ACTIVE"
    local color = is_offline and 0xFF0000 or 0x00E5FF
    local uptime_s = os.time() - startTime
    
    local pingVal = "N/A"
    pcall(function()
        local p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        pingVal = math.floor(p) .. " ms"
    end)

    return HttpService:JSONEncode({
        username = WEBHOOK_NAME,
        embeds = {{
            title = "🖥️ " .. BOT_NAME .. " MONITOR",
            color = color,
            fields = {
                { name = "User", value = "||"..LocalPlayer.Name.."||", inline = true },
                { name = "Status", value = "**" .. status_display .. "**", inline = true },
                { name = "Uptime", value = string.format("%02d:%02d:%02d", uptime_s//3600, (uptime_s%3600)//60, uptime_s%60), inline = true },
                { name = "RAM", value = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), inline = true },
                { name = "Ping", value = pingVal, inline = true }
            },
            footer = { text = "Pawfy Project • Live Updates" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
end

local function updateWebhook(is_offline)
    if not webhook then return end
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local success, r = pcall(function()
        return request({
            Url = url,
            Method = method,
            Headers = {["Content-Type"]="application/json"},
            Body = getPayload(is_offline)
        })
    end)
    
    if success and r and r.Body and not messageId then
        local data = HttpService:JSONDecode(r.Body)
        if data and data.id then messageId = data.id end
    end
end

-- GUI INPUT (Hanya jika belum ada config)
if not webhook then
    -- ... (Bagian GUI tetap sama seperti sebelumnya) ...
    -- (Pastikan untuk memanggil updateWebhook(false) setelah webhook di-save)
end

-- START LOGIC
updateWebhook(false)

task.spawn(function()
    while true do
        task.wait(5)
        if os.time() - lastUpdate >= INTERVAL then
            lastUpdate = os.time()
            -- Anti-AFK & GC
            pcall(function() game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)
            if collectgarbage then collectgarbage("collect") end
            -- Update
            pcall(function() updateWebhook(false) end)
        end
    end
end)

game:BindToClose(function() updateWebhook(true); task.wait(1) end)

-- LOAD MAIN
task.spawn(function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/pawfyproject-hub/pawfy/refs/heads/main/main.lua"))() end)
end)
