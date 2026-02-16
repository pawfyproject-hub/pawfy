--// PAWFY FARM MODE v2.5 (GLOBAL + HEALTH)
pcall(function()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not isfile("pawfy-config.json") then return end
local WEBHOOK_URL = HttpService:JSONDecode(readfile("pawfy-config.json")).webhook
if not WEBHOOK_URL then return end

local request = request or http_request or syn and syn.request
if not request then return end

local player = Players.LocalPlayer
if not player then return end
local USERNAME = player.Name

--------------------------------------------------
-- OPTIMIZER
--------------------------------------------------

if setfpscap then setfpscap(15) end
pcall(function() RunService:Set3dRenderingEnabled(false) end)

--------------------------------------------------
-- FORMAT TIME
--------------------------------------------------

local function formatTime(t)
    return os.date("%d-%m-%Y %H:%M:%S", t)
end

--------------------------------------------------
-- LOAD DATABASE
--------------------------------------------------

local DB_FILE = "pawfy-farm-db.json"
local farmDB = {}

if isfile(DB_FILE) then
    farmDB = HttpService:JSONDecode(readfile(DB_FILE))
end

farmDB[USERNAME] = farmDB[USERNAME] or {
    message_id = nil,
    last_join = "",
    last_seen = 0
}

farmDB._global_message_id = farmDB._global_message_id or nil

farmDB[USERNAME].last_join = formatTime(os.time())
farmDB[USERNAME].last_seen = os.time()

writefile(DB_FILE, HttpService:JSONEncode(farmDB))

--------------------------------------------------
-- STATUS CHECK
--------------------------------------------------

local function getStatus(userData)
    if os.time() - userData.last_seen > 180 then
        return "🔴 OFFLINE"
    else
        return "🟢 ACTIVE"
    end
end

--------------------------------------------------
-- COUNT HEALTH
--------------------------------------------------

local total = 0
local active = 0

for user,data in pairs(farmDB) do
    if user ~= "_global_message_id" then
        total += 1
        if os.time() - data.last_seen <= 180 then
            active += 1
        end
    end
end

local health = 0
if total > 0 then
    health = math.floor((active/total)*100)
end

local globalColor = 5763719
local healthStatus = "🟢 STABLE"

if health < 50 then
    globalColor = 16711680
    healthStatus = "🔴 CRITICAL"
elseif health < 80 then
    globalColor = 16776960
    healthStatus = "🟡 WARNING"
end

--------------------------------------------------
-- USER EMBED
--------------------------------------------------

local userStatus = getStatus(farmDB[USERNAME])

local userEmbed = {
    embeds = {{
        title = "🧊 Pawfy Farm Node",
        description =
            "👤 "..USERNAME..
            "\nStatus: "..userStatus..
            "\nLast Join: "..farmDB[USERNAME].last_join,
        color = userStatus == "🟢 ACTIVE" and 5763719 or 16711680
    }}
}

--------------------------------------------------
-- SEND OR EDIT USER MESSAGE
--------------------------------------------------

local messageId = farmDB[USERNAME].message_id

if messageId then
    request({
        Url = WEBHOOK_URL.."/messages/"..messageId,
        Method = "PATCH",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(userEmbed)
    })
else
    local response = request({
        Url = WEBHOOK_URL.."?wait=true",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(userEmbed)
    })
    if response and response.Body then
        local decoded = HttpService:JSONDecode(response.Body)
        farmDB[USERNAME].message_id = decoded.id
        writefile(DB_FILE, HttpService:JSONEncode(farmDB))
    end
end

--------------------------------------------------
-- GLOBAL EMBED
--------------------------------------------------

local globalEmbed = {
    embeds = {{
        title = "🚜 Pawfy Farm Global",
        description =
            "Total Accounts: "..total..
            "\nActive: "..active..
            "\nOffline: "..(total-active)..
            "\n\nFarm Health: "..health.."%"
            .."\nStatus: "..healthStatus,
        color = globalColor
    }}
}

local globalId = farmDB._global_message_id

if globalId then
    request({
        Url = WEBHOOK_URL.."/messages/"..globalId,
        Method = "PATCH",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(globalEmbed)
    })
else
    local response = request({
        Url = WEBHOOK_URL.."?wait=true",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(globalEmbed)
    })
    if response and response.Body then
        local decoded = HttpService:JSONDecode(response.Body)
        farmDB._global_message_id = decoded.id
        writefile(DB_FILE, HttpService:JSONEncode(farmDB))
    end
end

--------------------------------------------------
-- HEARTBEAT
--------------------------------------------------

task.spawn(function()
    while true do
        task.wait(60)
        if not isfile(DB_FILE) then continue end
        local data = HttpService:JSONDecode(readfile(DB_FILE))
        if data[USERNAME] then
            data[USERNAME].last_seen = os.time()
            writefile(DB_FILE, HttpService:JSONEncode(data))
        end
    end
end)

end)
