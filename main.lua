--// Pawfy Bot Notifier - Clean Multi Instance Final
--// Author: Pawfy Project

-- SERVICES
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or request

-- FILES
local CONFIG_FILE = "pawfy-config.json"
local SESSION_FILE = "pawfy-session.json"

-- CONSTANTS
local WEBHOOK_NAME = "Paw-Webhook"
local BOT_NAME = "Pawfy Bot Notifier"
local AVATAR_URL = "https://raw.githubusercontent.com/pawfyproject-hub/pawfy/main/pawfy.jpg"
local INTERVAL = 90 -- 1.5 menit

-- STATE
local webhook
local messageId
local startTime = os.time()
local lastTick = os.clock()

-- =========================
-- SESSION (UNIK PER INSTANCE)
-- =========================
local session
if isfile and isfile(SESSION_FILE) then
    session = HttpService:JSONDecode(readfile(SESSION_FILE))
else
    session = { id = HttpService:GenerateGUID(false) }
    writefile(SESSION_FILE, HttpService:JSONEncode(session))
end

-- =========================
-- NOTIFY (POPUP - ONLY UI)
-- =========================
local function notify(t, d)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = BOT_NAME,
            Text = t,
            Duration = d or 4
        })
    end)
end

-- =========================
-- CONFIG
-- =========================
local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end
end

local function saveConfig(data)
    writefile(CONFIG_FILE, HttpService:JSONEncode(data))
end

local cfg = loadConfig()
if cfg and cfg.webhook then
    webhook = cfg.webhook
end

-- =========================
-- GUI INPUT WEBHOOK
-- =========================
if not webhook then
    local gui = Instance.new("ScreenGui", game.CoreGui)
    gui.Name = "PawfyWebhookGui"

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.45, 0.3)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 20)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.fromScale(1, 0.3)
    title.BackgroundTransparency = 1
    title.Text = "Pawfy Bot Notifier"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 24

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.9, 0.25)
    box.Position = UDim2.fromScale(0.05, 0.4)
    box.PlaceholderText = "Paste Discord Webhook URL"
    box.BackgroundColor3 = Color3.fromRGB(30,30,30)
    box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.Gotham
    box.TextSize = 16
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.2)
    btn.Position = UDim2.fromScale(0.3, 0.7)
    btn.Text = "SAVE"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.TextColor3 = Color3.new(1,1,1)
    btn.BackgroundColor3 = Color3.fromRGB(0,200,255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)

    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord.com/api/webhooks") then
            webhook = box.Text
            saveConfig({ webhook = webhook })
            notify("Webhook saved", 3)
            gui:Destroy()
        end
    end)

    repeat task.wait() until webhook
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
    return p and math.floor(p:GetValue()) .. " ms" or "N/A"
end

local function mem()
    return string.format("%.2f MB", Stats:GetTotalMemoryUsageMb())
end

local function cpu()
    local c = Stats.PerformanceStats and Stats.PerformanceStats:FindFirstChild("CPU")
    return c and string.format("%.2f ms", c:GetValue()) or "N/A"
end

-- =========================
-- PAYLOAD
-- =========================
local function payload()
    return {
        username = WEBHOOK_NAME,
        avatar_url = AVATAR_URL,
        embeds = {{
            title = BOT_NAME,
            color = 0x00E5FF,
            fields = {
                { name = "User", value = LocalPlayer.Name, inline = true },
                { name = "Uptime", value = uptime(), inline = true },
                { name = "Memory", value = mem(), inline = true },
                { name = "CPU", value = cpu(), inline = true },
                { name = "Ping", value = ping(), inline = true }
            },
            footer = { text = "Pawfy Project" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
end

-- =========================
-- WEBHOOK SEND / EDIT
-- =========================
local function send()
    local r = request({
        Url = webhook .. "?wait=true",
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(payload())
    })
    if r and r.Body then
        messageId = HttpService:JSONDecode(r.Body).id
    end
end

local function edit()
    if not messageId then return end
    request({
        Url = webhook .. "/messages/" .. messageId,
        Method = "PATCH",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(payload())
    })
end

-- =========================
-- INIT
-- =========================
send()

RunService.Heartbeat:Connect(function()
    if os.clock() - lastTick >= INTERVAL then
        lastTick = os.clock()
        edit()
    end
end)
