--// PAWFY FARM MODE v3.1 STABLE LOCK
pcall(function()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local task = task

--------------------------------------------------
-- CONFIG & PLAYER
--------------------------------------------------

if not isfile("pawfy-config.json") then return end
local WEBHOOK_URL = HttpService:JSONDecode(readfile("pawfy-config.json")).webhook
if not WEBHOOK_URL then return end

local request = request or http_request or syn and syn.request
if not request then return end

local player = Players.LocalPlayer
if not player then return end
local USERNAME = player.Name

--------------------------------------------------
-- ULTRA OPTIMIZER
--------------------------------------------------

if setfpscap then setfpscap(15) end
pcall(function() RunService:Set3dRenderingEnabled(false) end)

--------------------------------------------------
-- TIME FORMAT
--------------------------------------------------

local function formatTime(t)
    return os.date("%d-%m-%Y %H:%M:%S", t)
end

--------------------------------------------------
-- DB FILES & LOCK
--------------------------------------------------

local DB_FILE = "pawfy-farm-db.json"
local LOCK_FILE = "pawfy-farm-db.lock"

local function acquireLock()
    while isfile(LOCK_FILE) do
        task.wait(0.1)
    end
    writefile(LOCK_FILE, "1")
end

local function releaseLock()
    if isfile(LOCK_FILE) then
        delfile(LOCK_FILE)
    end
end

--------------------------------------------------
-- READ DB SAFE
--------------------------------------------------

local farmDB = {}
if isfile(DB_FILE) then
    farmDB = HttpService:JSONDecode(readfile(DB_FILE))
end
farmDB._global_message_id = farmDB._global_message_id or nil
farmDB[USERNAME] = farmDB[USERNAME] or {
    last_join = "",
    last_seen = 0
}

-- Update self join & seen
farmDB[USERNAME].last_join = formatTime(os.time())
farmDB[USERNAME].last_seen = os.time()

--------------------------------------------------
-- SAVE DB SAFE
--------------------------------------------------

acquireLock()
writefile(DB_FILE, HttpService:JSONEncode(farmDB))
releaseLock()

--------------------------------------------------
-- BUILD GLOBAL EMBED
--------------------------------------------------

local total, active = 0, 0
local lines = ""

for user,data in pairs(farmDB) do
    if user ~= "_global_message_id" then
        total += 1
        local status = "🔴 OFFLINE"
        if os.time() - data.last_seen <= 180 then
            status = "🟢 ACTIVE"
            active += 1
        end
        lines = lines.."👤 "..user.." | "..status.." | Last Join: "..data.last_join.."\n"
    end
end

local health = 0
if total > 0 then
    health = math.floor((active/total)*100)
end

local healthStatus = "🟢 STABLE"
local color = 5763719
if health < 50 then
    healthStatus = "🔴 CRITICAL"
    color = 16711680
elseif health < 80 then
    healthStatus = "🟡 WARNING"
    color = 16776960
end

local embed = {
    embeds = {{
        title = "🚜 Pawfy Farm Controller v3.1",
        description =
            "Total: "..total..
            "\nActive: "..active..
            "\nOffline: "..(total-active)..
            "\nFarm Health: "..health.."%"
            .."\nStatus: "..healthStatus..
            "\n\n----------------------\n"..lines,
        color = color
    }}
}

--------------------------------------------------
-- SEND / EDIT GLOBAL MESSAGE
--------------------------------------------------

local function sendOrEdit()
    acquireLock()
    farmDB = isfile(DB_FILE) and HttpService:JSONDecode(readfile(DB_FILE)) or {}
    farmDB._global_message_id = farmDB._global_message_id or nil

    local globalId = farmDB._global_message_id

    if globalId then
        request({
            Url = WEBHOOK_URL.."/messages/"..globalId,
            Method = "PATCH",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(embed)
        })
    else
        local response = request({
            Url = WEBHOOK_URL.."?wait=true",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(embed)
        })
        if response and response.Body then
            local decoded = HttpService:JSONDecode(response.Body)
            farmDB._global_message_id = decoded.id
            writefile(DB_FILE, HttpService:JSONEncode(farmDB))
        end
    end
    releaseLock()
end

-- Random delay 0–2 detik untuk anti race
task.wait(math.random() * 2)
sendOrEdit()

--------------------------------------------------
-- HEARTBEAT (UPDATE LAST_SEEN)
--------------------------------------------------

task.spawn(function()
    while true do
        task.wait(60)
        acquireLock()
        local data = isfile(DB_FILE) and HttpService:JSONDecode(readfile(DB_FILE)) or {}
        if data[USERNAME] then
            data[USERNAME].last_seen = os.time()
            writefile(DB_FILE, HttpService:JSONEncode(data))
        end
        releaseLock()
        sendOrEdit()
    end
end)

end)
