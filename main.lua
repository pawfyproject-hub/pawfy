--// Pawfy Central Dashboard
--// Single Message | Multi Instance | Auto Recover | Anti 429

if not game:IsLoaded() then game.Loaded:Wait() end
if getgenv().PAWFY_CENTRAL then return end
getgenv().PAWFY_CENTRAL = true

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or request

local CONFIG_FILE = "pawfy-config.json"
local DASHBOARD_FILE = "pawfy-dashboard.json"

local INTERVAL = 60

local webhook
local dashboardMessageId
local startTime = os.time()
local sessionId = HttpService:GenerateGUID(false):sub(1,6)

-- =========================
-- LOAD CONFIG
-- =========================
local function loadJSON(path)
    if isfile and isfile(path) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok then return data end
    end
end

local function saveJSON(path,data)
    if writefile then
        writefile(path,HttpService:JSONEncode(data))
    end
end

local config = loadJSON(CONFIG_FILE)
if config and config.webhook then
    webhook = config.webhook
end

if not webhook then
    warn("Webhook tidak ditemukan.")
    return
end

local dashData = loadJSON(DASHBOARD_FILE) or {}

if dashData.messageId then
    dashboardMessageId = dashData.messageId
end

-- =========================
-- SAFE REQUEST
-- =========================
local function safeRequest(data)
    for i=1,5 do
        local r = request(data)
        if not r then task.wait(2) continue end

        if r.StatusCode == 200 or r.StatusCode == 204 then
            return r
        end

        if r.StatusCode == 429 then
            local retry = 5
            pcall(function()
                local body = HttpService:JSONDecode(r.Body)
                retry = tonumber(body.retry_after) or 5
            end)
            task.wait(retry)
        else
            task.wait(2)
        end
    end
end

-- =========================
-- STATS
-- =========================
local function uptime()
    local s = os.time() - startTime
    return string.format("%02d:%02d:%02d", s//3600, (s%3600)//60, s%60)
end

local function ping()
    local p = Stats.Network.ServerStatsItem["Data Ping"]
    return p and math.floor(p:GetValue()).."ms" or "N/A"
end

local function mem()
    return string.format("%.0fMB", Stats:GetTotalMemoryUsageMb())
end

local function cpu()
    local c = Stats.PerformanceStats and Stats.PerformanceStats:FindFirstChild("CPU")
    return c and string.format("%.0fms", c:GetValue()) or "N/A"
end

-- =========================
-- BUILD LINE
-- =========================
local function buildLine()
    return string.format(
        "🟢 %s | CPU %s | RAM %s | Ping %s | %s",
        LocalPlayer.Name.."#" .. sessionId,
        cpu(),
        mem(),
        ping(),
        uptime()
    )
end

-- =========================
-- CREATE DASHBOARD (AUTO RECOVER)
-- =========================
local function createDashboard()
    local payload = {
        embeds = {{
            title = "📊 Pawfy Central Monitor",
            description = "Initializing...",
            color = 0x00FF00,
            footer = {text = "Central Dashboard Mode"},
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    local r = safeRequest({
        Url = webhook.."?wait=true",
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(payload)
    })

    if r and r.Body then
        local decoded = HttpService:JSONDecode(r.Body)
        dashboardMessageId = decoded.id
        saveJSON(DASHBOARD_FILE,{messageId = dashboardMessageId})
    end
end

-- =========================
-- UPDATE DASHBOARD
-- =========================
local function updateDashboard()
    if not dashboardMessageId then
        createDashboard()
        return
    end

    task.wait(math.random(1,3)) -- reduce collision

    local r = safeRequest({
        Url = webhook.."/messages/"..dashboardMessageId,
        Method = "GET"
    })

    if not r or not r.Body then
        createDashboard()
        return
    end

    local decoded = HttpService:JSONDecode(r.Body)
    local oldDesc = decoded.embeds[1].description or ""

    local lines = {}
    for line in string.gmatch(oldDesc,"[^\n]+") do
        if not line:find(LocalPlayer.Name.."#"..sessionId) then
            table.insert(lines,line)
        end
    end

    table.insert(lines,buildLine())

    local newDesc = table.concat(lines,"\n")

    safeRequest({
        Url = webhook.."/messages/"..dashboardMessageId,
        Method = "PATCH",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode({
            embeds = {{
                title = "📊 Pawfy Central Monitor",
                description = newDesc,
                color = 0x00FF00,
                footer = {text="Central Dashboard Mode"},
                timestamp = DateTime.now():ToIsoDate()
            }}
        })
    })
end

-- =========================
-- LOOP
-- =========================
RunService.Heartbeat:Connect(function()
    if not dashboardMessageId then
        createDashboard()
    end
end)

task.spawn(function()
    while task.wait(INTERVAL) do
        updateDashboard()
    end
end)

-- =========================
-- CLOSE DETECT
-- =========================
game:BindToClose(function()
    if not dashboardMessageId then return end

    safeRequest({
        Url = webhook.."/messages/"..dashboardMessageId,
        Method = "PATCH",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode({
            embeds = {{
                title = "📊 Pawfy Central Monitor",
                description = "⚠ Instance "..LocalPlayer.Name.." left.",
                color = 0xFF0000
            }}
        })
    })
end)
