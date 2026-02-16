--// PAWFY STATUS ONLY DASHBOARD (ULTRA LIGHT)
pcall(function()

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local HttpService = game:GetService("HttpService")

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
-- AUTO DETECT PACKAGE
--------------------------------------------------

local PACKAGE_NAME = "com.pawfy.unknown"

for i=1,5 do
    if getgenv()["PAWFY_SYS"..i] then
        PACKAGE_NAME = "com.pawfy.sys"..i
    end
end

--------------------------------------------------
-- GLOBAL TABLE
--------------------------------------------------

_G.PAWFY_STATUS = _G.PAWFY_STATUS or {}
_G.PAWFY_MASTER = _G.PAWFY_MASTER or PACKAGE_NAME

local IS_MASTER = (_G.PAWFY_MASTER == PACKAGE_NAME)

--------------------------------------------------
-- HEARTBEAT UPDATE (LOCAL INSTANCE)
--------------------------------------------------

task.spawn(function()
    while true do
        _G.PAWFY_STATUS[PACKAGE_NAME] = {
            lastSeen = tick()
        }
        task.wait(5)
    end
end)

--------------------------------------------------
-- LOAD MESSAGE ID
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
    local hasOffline = false

    for name,data in pairs(_G.PAWFY_STATUS) do

        local status = "🟢 ONLINE"

        if now - data.lastSeen > 90 then
            status = "🔴 OFFLINE"
            hasOffline = true
        end

        table.insert(fields,{
            name = name,
            value = status,
            inline = true
        })
    end

    return {
        embeds = {{
            title = "🧊 Pawfy Instance Status",
            color = hasOffline and 16711680 or 5763719,
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
        request({
            Url = WEBHOOK_URL.."/messages/"..MESSAGE_ID,
            Method = "PATCH",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    else
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
-- MASTER LOOP (REAL EDIT)
--------------------------------------------------

if IS_MASTER then
    task.spawn(function()
        while true do
            sendOrEdit()
            task.wait(1800) -- update tiap 30 menit
        end
    end)
end

end)
