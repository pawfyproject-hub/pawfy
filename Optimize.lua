--// PAWFY ULTRA REAL EDIT DASHBOARD
pcall(function()

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

--------------------------------------------------
-- LOAD CONFIG
--------------------------------------------------

local WEBHOOK_URL
local MESSAGE_FILE = "pawfy-message.json"

pcall(function()
    if isfile("pawfy-config.json") then
        local raw = readfile("pawfy-config.json")
        local data = HttpService:JSONDecode(raw)
        WEBHOOK_URL = data.webhook
    end
end)

if not WEBHOOK_URL then
    warn("Webhook tidak ditemukan!")
    return
end

--------------------------------------------------
-- PACKAGE DETECT
--------------------------------------------------

local PACKAGE_NAME = "com.pawfy.unknown"

for i=1,5 do
    if getgenv()["PAWFY_SYS"..i] then
        PACKAGE_NAME = "com.pawfy.sys"..i
    end
end

--------------------------------------------------
-- GLOBAL DATA TABLE
--------------------------------------------------

_G.PAWFY_DASHBOARD = _G.PAWFY_DASHBOARD or {}
_G.PAWFY_MASTER = _G.PAWFY_MASTER or PACKAGE_NAME

local IS_MASTER = (_G.PAWFY_MASTER == PACKAGE_NAME)

--------------------------------------------------
-- FPS TRACK
--------------------------------------------------

local fpsCurrent = 0
local fpsAvg = 0
local fpsMin = 999
local fpsMax = 0
local frameCount = 0
local totalFps = 0
local startTime = tick()

RunService.Heartbeat:Connect(function(dt)
    local fps = math.floor(1/dt)
    fpsCurrent = fps

    frameCount += 1
    totalFps += fps

    if fps < fpsMin then fpsMin = fps end
    if fps > fpsMax then fpsMax = fps end

    fpsAvg = math.floor(totalFps/frameCount)
end)

--------------------------------------------------
-- FORMAT UPTIME
--------------------------------------------------

local function formatUptime(sec)
    local m = math.floor(sec/60)
    local h = math.floor(m/60)
    local mm = m%60
    return string.format("%02d:%02d", h, mm)
end

--------------------------------------------------
-- UPDATE LOCAL DATA
--------------------------------------------------

task.spawn(function()
    while true do
        _G.PAWFY_DASHBOARD[PACKAGE_NAME] = {
            uptime = formatUptime(tick()-startTime),
            fps = fpsCurrent,
            avg = fpsAvg,
            min = fpsMin,
            max = fpsMax,
            memory = math.floor(Stats:GetTotalMemoryUsageMb()),
            lastSeen = tick()
        }
        task.wait(5)
    end
end)

--------------------------------------------------
-- DISCORD MESSAGE ID
--------------------------------------------------

local MESSAGE_ID = nil

pcall(function()
    if isfile(MESSAGE_FILE) then
        local raw = readfile(MESSAGE_FILE)
        MESSAGE_ID = HttpService:JSONDecode(raw).id
    end
end)

--------------------------------------------------
-- BUILD EMBED
--------------------------------------------------

local function buildEmbed()

    local fields = {}
    local now = tick()

    for name,data in pairs(_G.PAWFY_DASHBOARD) do

        local status = "🟢 ONLINE"
        local colorEmoji = "🟢"

        if now - data.lastSeen > 90 then
            status = "🔴 OFFLINE"
            colorEmoji = "🔴"
        end

        table.insert(fields,{
            name = colorEmoji.." "..name,
            value =
                "Status: "..status..
                "\nUptime: "..data.uptime..
                "\nFPS: "..data.fps.." (avg "..data.avg..")"..
                "\nMin/Max: "..data.min.."/"..data.max..
                "\nMemory: "..data.memory.." MB",
            inline = false
        })
    end

    return {
        embeds = {{
            title = "🧊 Pawfy Cloudphone Dashboard",
            color = 3447003,
            fields = fields,
            footer = {
                text = "Realtime Edit • Offline Detect 90s"
            }
        }}
    }
end

--------------------------------------------------
-- SEND / EDIT MESSAGE
--------------------------------------------------

local function sendOrEdit()

    local payload = buildEmbed()

    if MESSAGE_ID then
        -- EDIT EXISTING MESSAGE
        request({
            Url = WEBHOOK_URL.."/messages/"..MESSAGE_ID,
            Method = "PATCH",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    else
        -- SEND FIRST MESSAGE
        local response = request({
            Url = WEBHOOK_URL.."?wait=true",
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode(payload)
        })

        if response and response.Body then
            local decoded = HttpService:JSONDecode(response.Body)
            MESSAGE_ID = decoded.id
            writefile(MESSAGE_FILE,
                HttpService:JSONEncode({id = MESSAGE_ID})
            )
        end
    end
end

--------------------------------------------------
-- MASTER LOOP (REAL EDIT 30M)
--------------------------------------------------

if IS_MASTER then
    task.spawn(function()
        while true do
            sendOrEdit()
            task.wait(1800) -- 30 menit
        end
    end)
end

end)
