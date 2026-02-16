-- ===================================
--        Pawfy Sys Monitor
--        Production Edition
--        INACTIVE Hide Details
-- ===================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local WEBHOOK_URL = "ISI_WEBHOOK_KAMU_DISINI"

local USERNAME = Players.LocalPlayer.Name
local START_TIME = tick()

local DASHBOARD_MESSAGE_ID = nil
local INSTANCE_DATA = {}

local TIMEOUT = 120 -- detik sebelum dianggap INACTIVE

-- ================= Utility =================

local function formatUptime(sec)
    local h = math.floor(sec/3600)
    local m = math.floor((sec%3600)/60)
    return string.format("%02dh %02dm", h, m)
end

local function getMemory()
    return math.floor(collectgarbage("count") / 1024)
end

local function getPing()
    return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
end

local function buildDescription()

    local totalRam = 0
    local activeCount = 0
    local now = tick()

    local desc = ""
    desc = desc .. "╔════════════════════════════╗\n"
    desc = desc .. "        PAWFY SYS MONITOR\n"
    desc = desc .. "╚════════════════════════════╝\n\n"

    for _, data in pairs(INSTANCE_DATA) do

        if now - data.lastUpdate > TIMEOUT then
            -- INACTIVE
            desc = desc .. "◆ **"..data.user.."**\n"
            desc = desc .. "   └ 🔴 INACTIVE - Last "..data.lastSeen.."\n\n"
        else
            -- ONLINE
            totalRam += data.memory
            activeCount += 1

            desc = desc .. "◆ **"..data.user.."**\n"
            desc = desc .. "   ├ Status   : 🟢 ONLINE\n"
            desc = desc .. "   ├ Uptime   : "..data.uptime.."\n"
            desc = desc .. "   ├ Memory   : "..data.memory.." MB\n"
            desc = desc .. "   └ Ping     : "..data.ping.."\n\n"
        end
    end

    desc = desc .. "────────────────────────────\n"
    desc = desc .. "Total RAM Usage : "..totalRam.." MB\n"
    desc = desc .. "Active Instance : "..activeCount.."\n"
    desc = desc .. "────────────────────────────\n"
    desc = desc .. "Pawfy Project | Last Update: "..os.date("%X")

    return desc
end

-- ================= Core =================

local function updateDashboard()

    INSTANCE_DATA[USERNAME] = {
        user = USERNAME,
        uptime = formatUptime(tick() - START_TIME),
        memory = getMemory(),
        ping = getPing(),
        lastUpdate = tick(),
        lastSeen = os.date("%X")
    }

    local list = {}
    for _, v in pairs(INSTANCE_DATA) do
        table.insert(list, v)
    end
    INSTANCE_DATA = list

    local payload = {
        username = "Pawfy Sys Monitor",
        embeds = {{
            title = "🖥️ Pawfy Sys Monitor",
            description = buildDescription(),
            color = 16766720
        }}
    }

    if DASHBOARD_MESSAGE_ID then
        request({
            Url = WEBHOOK_URL.."/messages/"..DASHBOARD_MESSAGE_ID,
            Method = "PATCH",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    else
        local response = request({
            Url = WEBHOOK_URL.."?wait=true",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })

        if response and response.Body then
            local data = HttpService:JSONDecode(response.Body)
            DASHBOARD_MESSAGE_ID = data.id
        end
    end
end

-- Anti collision start
task.wait(math.random(2,5))

-- Update loop
while true do
    pcall(updateDashboard)
    task.wait(60 + math.random(-10,10))
end
