--// =========================
--// Pawfy Bot Notifier
--// Hybrid | Low CPU | Guarded
--// =========================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or request

--// =========================
--// CONFIG
--// =========================

local CONFIG_FILE = "pawfy-config.json"
local WEBHOOK_URL
local MESSAGE_ID
local START_TIME = os.time()

local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local BOT_NAME   = "Paw-Webhook"
local TITLE_NAME = "Pawfy Bot Notifier"

-- Interval 1–2 menit (random biar natural)
local MIN_INTERVAL = 60
local MAX_INTERVAL = 120

--// =========================
--// CONFIG LOAD / SAVE
--// =========================

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if ok then return data end
    end
end

local function saveConfig(data)
    if writefile then
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end
end

local cfg = loadConfig()
if cfg and cfg.webhook then
    WEBHOOK_URL = cfg.webhook
    MESSAGE_ID = cfg.messageId
end

--// =========================
--// AUTO STOP IF NO WEBHOOK
--// =========================

if not WEBHOOK_URL or WEBHOOK_URL == "" then
    warn("[Pawfy] Webhook belum diset.")
    return
end

--// =========================
--// STATS FUNCTIONS
--// =========================

local function formatTime(sec)
    return string.format(
        "%02d:%02d:%02d",
        sec // 3600,
        (sec % 3600) // 60,
        sec % 60
    )
end

local function getPing()
    local p = Stats.Network.ServerStatsItem["Data Ping"]
    return p and math.floor(p:GetValue()) .. " ms" or "N/A"
end

local function getMemory()
    return string.format("%.2f MB", Stats:GetTotalMemoryUsageMb())
end

local function getCPU()
    local cpu = Stats.PerformanceStats and Stats.PerformanceStats:FindFirstChild("CPU")
    return cpu and string.format("%.2f ms", cpu:GetValue()) or "N/A"
end

local function getExecutor()
    return identifyexecutor and identifyexecutor() or "Unknown"
end

local function box(v)
    return "```" .. tostring(v) .. "```"
end

--// =========================
--// PAYLOAD
--// =========================

local function buildPayload()
    return {
        username = BOT_NAME,
        avatar_url = AVATAR_URL,
        embeds = {{
            title = TITLE_NAME,
            color = 0x00E5FF,
            fields = {
                { name = "Username", value = box(LocalPlayer.Name), inline = true },
                { name = "Uptime", value = box(formatTime(os.time() - START_TIME)), inline = true },
                { name = "Memory", value = box(getMemory()), inline = true },
                { name = "CPU", value = box(getCPU()), inline = true },
                { name = "Ping", value = box(getPing()), inline = true },
                { name = "Executor", value = box(getExecutor()), inline = true },
            },
            footer = {
                text = "Pawfy Project",
                icon_url = AVATAR_URL
            },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
end

--// =========================
--// SAFE REQUEST (ANTI ERROR)
--// =========================

local function safeRequest(opt)
    local ok, res = pcall(function()
        return request(opt)
    end)
    if not ok or not res then
        warn("[Pawfy] Webhook request failed.")
        return nil
    end
    return res
end

--// =========================
--// SEND / EDIT WEBHOOK
--// =========================

local function sendWebhook()
    local res = safeRequest({
        Url = WEBHOOK_URL .. "?wait=true",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(buildPayload())
    })

    if res and res.Body then
        local body = HttpService:JSONDecode(res.Body)
        MESSAGE_ID = body.id
        saveConfig({
            webhook = WEBHOOK_URL,
            messageId = MESSAGE_ID
        })
    end
end

local function editWebhook()
    if not MESSAGE_ID then
        sendWebhook()
        return
    end

    safeRequest({
        Url = WEBHOOK_URL .. "/messages/" .. MESSAGE_ID,
        Method = "PATCH",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(buildPayload())
    })
end

--// =========================
--// HYBRID LOOP (LOW CPU)
--// =========================

task.spawn(function()
    sendWebhook()

    while task.wait(math.random(MIN_INTERVAL, MAX_INTERVAL)) do
        editWebhook()
    end
end)
