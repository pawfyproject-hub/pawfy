--// ==================================================
--// Pawfy Bot Notifier
--// Hybrid Popup (1x) + Multi Instance Safe
--// ==================================================

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- Executor HTTP
local request = http_request or (http and http.request) or request
if not request then
    warn("[Pawfy] Executor tidak mendukung http_request")
    return
end

-- ==================================================
-- GLOBAL CONFIG (SHARED)
-- ==================================================

local GLOBAL_CONFIG = "pawfy-global.json"

-- Instance Config (UNIK PER INSTANCE)
local INSTANCE_ID   = game.JobId
local INSTANCE_NAME = "Instance " .. string.sub(INSTANCE_ID, 1, 6)
local INSTANCE_CFG  = "pawfy-" .. INSTANCE_ID .. ".json"

-- Branding
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local BOT_NAME   = "Paw-Webhook"
local TITLE_NAME = "Pawfy Bot Notifier — " .. INSTANCE_NAME

-- Interval
local MIN_INTERVAL = 60
local MAX_INTERVAL = 120

local START_TIME = os.time()
local WEBHOOK_URL
local MESSAGE_ID

-- ==================================================
-- FILE UTILS
-- ==================================================

local function readJSON(path)
    if isfile and isfile(path) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok then return data end
    end
end

local function writeJSON(path, data)
    if writefile then
        writefile(path, HttpService:JSONEncode(data))
    end
end

-- ==================================================
-- POPUP (ONLY IF WEBHOOK NOT SET)
-- ==================================================

local function popupWebhook()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Pawfy-Webhook-GUI"
    gui.IgnoreGuiInset = true
    gui.Parent = game.CoreGui

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.45, 0.3)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,20)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.fromScale(1, 0.3)
    title.BackgroundTransparency = 1
    title.Text = "Pawfy Webhook Setup"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 24
    title.TextColor3 = Color3.new(1,1,1)

    local input = Instance.new("TextBox", frame)
    input.Size = UDim2.fromScale(0.9, 0.25)
    input.Position = UDim2.fromScale(0.05, 0.38)
    input.PlaceholderText = "Paste Discord Webhook URL"
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.Gotham
    input.TextSize = 16
    input.TextColor3 = Color3.new(1,1,1)
    input.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,14)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.45, 0.22)
    btn.Position = UDim2.fromScale(0.275, 0.7)
    btn.Text = "SAVE"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.TextColor3 = Color3.new(1,1,1)
    btn.BackgroundColor3 = Color3.fromRGB(0,229,255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,16)

    btn.MouseButton1Click:Connect(function()
        if input.Text:find("discord.com/api/webhooks") then
            WEBHOOK_URL = input.Text
            writeJSON(GLOBAL_CONFIG, { webhook = WEBHOOK_URL })
            gui:Destroy()
        end
    end)

    repeat task.wait() until WEBHOOK_URL
end

-- ==================================================
-- LOAD GLOBAL WEBHOOK
-- ==================================================

local gcfg = readJSON(GLOBAL_CONFIG)
if gcfg and gcfg.webhook then
    WEBHOOK_URL = gcfg.webhook
else
    popupWebhook()
end

-- ==================================================
-- LOAD INSTANCE MESSAGE ID
-- ==================================================

local icfg = readJSON(INSTANCE_CFG)
if icfg and icfg.messageId then
    MESSAGE_ID = icfg.messageId
end

-- ==================================================
-- STATS
-- ==================================================

local function formatTime(sec)
    return string.format("%02d:%02d:%02d", sec//3600, (sec%3600)//60, sec%60)
end

local function getPing()
    local p = Stats.Network.ServerStatsItem["Data Ping"]
    return p and math.floor(p:GetValue()).." ms" or "N/A"
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
    return "```"..tostring(v).."```"
end

-- ==================================================
-- PAYLOAD
-- ==================================================

local function buildPayload()
    return {
        username = BOT_NAME,
        avatar_url = AVATAR_URL,
        embeds = {{
            title = TITLE_NAME,
            color = 0x00E5FF,
            fields = {
                { name="Username", value=box(LocalPlayer.Name), inline=true },
                { name="Uptime", value=box(formatTime(os.time()-START_TIME)), inline=true },
                { name="Memory", value=box(getMemory()), inline=true },
                { name="CPU", value=box(getCPU()), inline=true },
                { name="Ping", value=box(getPing()), inline=true },
                { name="Executor", value=box(getExecutor()), inline=true },
            },
            footer = { text="Pawfy Project", icon_url=AVATAR_URL },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
end

-- ==================================================
-- WEBHOOK SEND / EDIT
-- ==================================================

local function safeRequest(opt)
    local ok, res = pcall(function()
        return request(opt)
    end)
    return ok and res or nil
end

local function sendWebhook()
    local res = safeRequest({
        Url = WEBHOOK_URL .. "?wait=true",
        Method = "POST",
        Headers = { ["Content-Type"]="application/json" },
        Body = HttpService:JSONEncode(buildPayload())
    })

    if res and res.Body then
        local body = HttpService:JSONDecode(res.Body)
        MESSAGE_ID = body.id
        writeJSON(INSTANCE_CFG, { messageId = MESSAGE_ID })
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
        Headers = { ["Content-Type"]="application/json" },
        Body = HttpService:JSONEncode(buildPayload())
    })
end

-- ==================================================
-- LOOP
-- ==================================================

task.spawn(function()
    editWebhook()
    while true do
        task.wait(math.random(MIN_INTERVAL, MAX_INTERVAL))
        editWebhook()
    end
end)
