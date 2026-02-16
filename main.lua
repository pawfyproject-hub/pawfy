--// Pawfy Project - Original Logic (Fixed Symbols)
--// Tetap menggunakan alur asli Pawfy Project yang sudah lancar

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local request = http_request or (http and http.request) or (syn and syn.request) or request

-- OPTIMIZE (Disesuaikan agar tidak mengganggu thread utama)
pcall(function()
    if setfpscap then setfpscap(15) end
    RunService:Set3dRenderingEnabled(false)
end)

local CONFIG_FILE = "pawfy-config.json"
local WEBHOOK_NAME = "Pawfy Sys Notifier"
local BOT_NAME = "Pawfy Sys"
local INTERVAL = 50 

local webhook
local messageId
local startTime = os.time()

-- LOAD CONFIG ASLI
if isfile(CONFIG_FILE) then
    local cfg = HttpService:JSONDecode(readfile(CONFIG_FILE))
    if cfg and cfg.webhook then webhook = cfg.webhook end
end

-- GUI INPUT ASLI (Hanya muncul jika belum ada config)
if not webhook then
    local gui = Instance.new("ScreenGui", game.CoreGui)
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromScale(0.3, 0.2)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    
    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.fromScale(0.8, 0.4)
    box.Position = UDim2.fromScale(0.1, 0.1)
    box.PlaceholderText = "Webhook URL"
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(0.4, 0.3)
    btn.Position = UDim2.fromScale(0.3, 0.6)
    btn.Text = "SAVE"
    
    btn.MouseButton1Click:Connect(function()
        if box.Text:find("discord") then
            webhook = box.Text
            writefile(CONFIG_FILE, HttpService:JSONEncode({webhook = webhook}))
            gui:Destroy()
        end
    end)
    repeat task.wait() until webhook
end

-- FUNGSI PAYLOAD (Simbol diletakkan di Baris Status sesuai permintaan)
local function getPayload(is_offline)
    local uptime_s = os.time() - startTime
    local ping = "N/A"
    pcall(function()
        ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
    end)

    return HttpService:JSONEncode({
        username = WEBHOOK_NAME,
        embeds = {{
            title = "🖥️ " .. BOT_NAME .. " MONITOR",
            color = is_offline and 16711680 or 65535,
            fields = {
                { name = "User", value = "||"..LocalPlayer.Name.."||", inline = true },
                { name = "Status", value = is_offline and "**🔴 INACTIVE**" or "**🟢 ACTIVE**", inline = true },
                { name = "Uptime", value = string.format("%02d:%02d:%02d", uptime_s//3600, (uptime_s%3600)//60, uptime_s%60), inline = true },
                { name = "Memory", value = string.format("%.2f MB", Stats:GetTotalMemoryUsageMb()), inline = true },
                { name = "Ping", value = ping, inline = true }
            },
            footer = { text = "Pawfy Project • Verified Update" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
end

-- LOGIKA UPDATE (Menggunakan alur asli Pawfy Project)
local function updateStatus(is_offline)
    local url = messageId and (webhook .. "/messages/" .. messageId) or (webhook .. "?wait=true")
    local method = messageId and "PATCH" or "POST"

    local res = request({
        Url = url,
        Method = method,
        Headers = {["Content-Type"] = "application/json"},
        Body = getPayload(is_offline)
    })

    if res and res.Body and not messageId then
        local data = HttpService:JSONDecode(res.Body)
        if data and data.id then messageId = data.id end
    end
end

-- LOOPING ASLI PAWFY PROJECT
task.spawn(function()
    updateStatus(false)
    while task.wait(INTERVAL) do
        -- Anti-AFK
        pcall(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
        
        -- Update
        updateStatus(false)
    end
end)

game:BindToClose(function()
    updateStatus(true)
end)
