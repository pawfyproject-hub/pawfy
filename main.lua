-- =====================================================
-- Z-HYBRID NOTIFIER (FINAL STABLE)
-- Author : Zinnc
-- Mode   : Hybrid (Sleep + Heartbeat Detector)
-- =====================================================

-- ===== ANTI DOUBLE EXECUTE =====
if getgenv and getgenv().Z_HYBRID_LOADED then return end
if getgenv then getgenv().Z_HYBRID_LOADED = true end

-- ========= CONFIG =========
local BASE_INTERVAL = 90      -- detik (update normal)
local MIN_INTERVAL  = 30      -- jarak minimal antar update
local CPU_SPIKE     = 5       -- ms
local PING_SPIKE    = 30      -- ms
local MEM_SPIKE     = 50      -- MB
-- ==========================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local request = http_request or http and http.request or request

local CONFIG_FILE = "Z-Config.json"
local webhook
local messageId
local startTime = os.time()
local lastUpdate = 0

local AVATAR_URL = "https://raw.githubusercontent.com/zinnc-haha/Main/main/file_00000000bba47208a885beff68d20247.png"

-- ===== LOAD CONFIG =====
if isfile(CONFIG_FILE) then
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and data and data.webhook then
        webhook = data.webhook
    end
end

if not webhook or webhook == "" then
    warn("[Z-Hybrid] Webhook tidak ditemukan di Z-Config.json")
    return
end

-- ===== STATS FUNCTIONS =====
local function getPing()
    local p = Stats.Network.ServerStatsItem["Data Ping"]
    return p and math.floor(p:GetValue()) or 0
end

local function getMemory()
    return Stats:GetTotalMemoryUsageMb()
end

local function getCPU()
    local cpu = Stats.PerformanceStats and Stats.PerformanceStats:FindFirstChild("CPU")
    return cpu and cpu:GetValue() or 0
end

local function formatTime(sec)
    return string.format("%02d:%02d:%02d", sec//3600, (sec%3600)//60, sec%60)
end

local function box(v)
    return "```" .. tostring(v) .. "```"
end

local function getExecutor()
    return identifyexecutor and identifyexecutor() or "Unknown"
end

-- ===== PAYLOAD =====
local function buildPayload()
    return {
        username = "Z-WebHook",
        avatar_url = AVATAR_URL,
        embeds = {{
            title = "Roblox Stats (Hybrid)",
            color = 0x00E5FF,
            fields = {
                { name = "Username", value = box(LocalPlayer.Name), inline = true },
                { name = "Uptime", value = box(formatTime(os.time() - startTime)), inline = true },
                { name = "Memory", value = box(string.format("%.2f MB", getMemory())), inline = true },
                { name = "CPU", value = box(string.format("%.2f ms", getCPU())), inline = true },
                { name = "Ping", value = box(getPing() .. " ms"), inline = true },
                { name = "Executor", value = box(getExecutor()), inline = true },
            },
            footer = {
                text = "Z-Hybrid Notifier",
                icon_url = AVATAR_URL
            },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
end

-- ===== WEBHOOK HANDLER =====
local function sendWebhook()
    local ok, res = pcall(function()
        return request({
            Url = webhook .. "?wait=true",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(buildPayload())
        })
    end)

    if ok and res and res.Body then
        local body = HttpService:JSONDecode(res.Body)
        messageId = body.id
        lastUpdate = os.clock()
        return true
    end
    return false
end

local function editWebhook()
    if os.clock() - lastUpdate < MIN_INTERVAL then
        return
    end

    if not messageId then
        sendWebhook()
        return
    end

    local ok = pcall(function()
        request({
            Url = webhook .. "/messages/" .. messageId,
            Method = "PATCH",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(buildPayload())
        })
    end)

    if not ok then
        messageId = nil
        sendWebhook()
    else
        lastUpdate = os.clock()
    end
end

-- ===== INITIAL SEND =====
sendWebhook()

-- ===== MODE 1: NORMAL INTERVAL (HEMAT CPU) =====
task.spawn(function()
    while task.wait(BASE_INTERVAL) do
        editWebhook()
    end
end)

-- ===== MODE 2: HEARTBEAT DETECTOR (SPIKE ONLY) =====
local lastCPU = getCPU()
local lastPing = getPing()
local lastMem = getMemory()

RunService.Heartbeat:Connect(function()
    local cpu = getCPU()
    local ping = getPing()
    local mem = getMemory()

    if math.abs(cpu - lastCPU) >= CPU_SPIKE
    or math.abs(ping - lastPing) >= PING_SPIKE
    or math.abs(mem - lastMem) >= MEM_SPIKE then
        editWebhook()
    end

    lastCPU = cpu
    lastPing = ping
    lastMem = mem
end)
