local BotState = _G.State :: any

local HttpService: HttpService = game:GetService("HttpService")
local Players: Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local Workspace: Workspace = game:GetService("Workspace")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventsModule: ModuleScript = ReplicatedStorage:WaitForChild("Events") :: ModuleScript
local BuffsModule: ModuleScript = ReplicatedStorage:FindFirstChild("Buffs") :: ModuleScript
local OstimeModule: ModuleScript = ReplicatedStorage:FindFirstChild("OsTime") :: ModuleScript
local LocalFXEvent: RemoteEvent = EventsModule:WaitForChild("LocalFX") :: RemoteEvent
local Buffs = require(BuffsModule)
local Events = require(EventsModule)
local OsTime = require(OstimeModule)

local reportedUnmapped: { [string]: boolean } = {}
local DebugService = {}
local preciseChains = {}
local activeBuffs = {}

local lastUpdate = 0
local UPDATE_DT = 0.1

local tokenMap = loadstring(game:HttpGet("https://raw.githubusercontent.com/VanhoenackerThibault/thibault-test-project-luau/refs/heads/main/Helpers/TokenMap.luau"))()

local WEBHOOK_URL: string = "https://discord.com/api/webhooks/1515773551834038332/Qe_CpwRILhIHCwk5frIamWZd1bMDEpnfrYX-av-n2nFEjc7_HOBYQnyxNlaPxf70XWjg"
local BILLBOARD_TTL: number = 10
local BILLBOARD_MAX_DST: number = 150

function DebugService.Init(services): nil
    DebugService.Services = services
    return
end

local function extractIdNumber(imgIdOrUrl)
    if type(imgIdOrUrl) ~= "string" then return nil end

    local id = imgIdOrUrl:match("rbxassetid://(%d+)")
    if id then return id end

    id = imgIdOrUrl:match("asset/%?id=(%d+)")
    if id then return id end

    id = imgIdOrUrl:match("(%d+)")
    return id
end

local function normalizeImageId(image)
    if type(image) ~= "string" or image == "" then return nil end

    image = image:gsub("^%s+", ""):gsub("%s+$", "")

    local id = image:match("^rbxassetid://(%d+)$")
    if id then return "rbxassetid://" .. id end

    id = image:match("asset/%?id=(%d+)")
    if id then return "rbxassetid://" .. id end

    id = image:match("^(%d+)$")
    if id then return "rbxassetid://" .. id end

    return image
end

local function sendUnmappedToWebhook(imgId)
    if reportedUnmapped[imgId] then return end

    local idNum = extractIdNumber(imgId)
    if not idNum then return end

    local link = "https://www.roblox.com/library/" .. idNum
    local payload = {
        content = string.format(
            "Unmapped Bee Swarm token detected:\nImageId: `%s`\nLink: %s",
            imgId,
            link
        ),
    }

    local encoded = HttpService:JSONEncode(payload)

    local ok, err = pcall(function()
        if request then
            request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = encoded })
        elseif http_request then
            http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = encoded })
        elseif syn and syn.request then
            syn.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = encoded })
        elseif fluxus and fluxus.request then
            fluxus.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = encoded })
        end
    end)

    if ok then
        reportedUnmapped[imgId] = true
    else
        warn("[FarmService] Failed to send unmapped token to webhook:", err)
    end
end

local function showTokenBillboard(part, tokenName)
    if not part or not part:IsA("BasePart") then return end
    if not playerGui then return end

    local guiName = "TokenBillboard_" .. part:GetDebugId()
    local gui = playerGui:FindFirstChild(guiName)

    if not gui then
        gui = Instance.new("BillboardGui")
        gui.Name = guiName
        gui.Adornee = part
        gui.Size = UDim2.new(0, 200, 0, 50)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        gui.AlwaysOnTop = true
        gui.MaxDistance = BILLBOARD_MAX_DST
        gui.Parent = playerGui

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 0.5
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.BorderSizePixel = 0
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextStrokeTransparency = 0.5
        label.TextScaled = true
        label.Font = Enum.Font.Code
        label.Parent = gui

        task.delay(BILLBOARD_TTL, function()
            if gui and gui.Parent then
                gui:Destroy()
            end
        end)
    end

    local label = gui:FindFirstChild("Label")
    if label then
        label.Text = tokenName
    end
end

function GetTokensSortedByDistance(): nil
    local collectiblesFolder: Folder? = Workspace:FindFirstChild("Collectibles") :: Folder
    if collectiblesFolder == nil then
        warn("[DebugService] Collectibles folder not found in Workspace")
        return nil
    end

    for _, itemInstance: Instance in ipairs(collectiblesFolder:GetChildren()) do
        if not itemInstance:IsA("Part") then
            continue
        end

        local item: Part = itemInstance

        local decal: Decal? = item:FindFirstChild("FrontDecal") :: Decal?
        if decal == nil then
            continue
        end

        local imgId: string? = normalizeImageId(decal.Texture)
        if imgId == nil then
            continue
        end

        local name: string? = tokenMap[imgId]

        if name ~= nil then
            showTokenBillboard(item, name)
        else
            sendUnmappedToWebhook(imgId)
        end
    end

    return nil
end

task.spawn(function()
    while task.wait(0.2) do
        if BotState.showDebugInfo then 
            GetTokensSortedByDistance()
        end
    end
end)

function makeBillboard(entry, part): nil
    if not part then
        return
    end

    local existing = part:FindFirstChild("TP_LocalFXBillboard")
    if existing then
        existing:Destroy()
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TP_LocalFXBillboard"
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 280, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true

    -- Example: "FEID 60 | ID 101 | Target 1/3"
    label.Text = string.format(
        "FEID %s | ID %s | Target %d/3",
        tostring(entry.FEID),
        tostring(entry.ID),
        entry.Index
    )

    label.Parent = billboard

    task.delay(3, function()
        if billboard.Parent then
            billboard:Destroy()
        end

        preciseChains[entry.FEID] = {}
    end)

    return
end

LocalFXEvent.OnClientEvent:Connect(function(effectName: string, data: {Action: string, Pos: Vector3, ID: number, FEID: number, Player: Player})
    if not BotState.showDebugInfo then 
        return
    end

    if effectName ~= "LocalTargetPracticeBeam" then
        return
    end

    if type(data) ~= "table" then
        return
    end

    if not data.Player then 
        return
    end

    if tostring(data.Player.Name) ~= tostring(localPlayer.Name) then 
        return
    end

    if data.Action ~= "Make" then
        return
    end

    if not data.Pos or typeof(data.Pos) ~= "Vector3" then
        return
    end

    local id: number = data.ID :: number
    local feid: number = data.FEID :: number

    if not feid then
        feid = 9999
    end

    if not preciseChains[feid] then
        preciseChains[feid] = {}
    end

    local list = preciseChains[feid]

    -- new entry for this FEID chain
    local entry = {
        Pos = data.Pos,
        Index = #list + 1,
        ID = id,
        FEID = feid,
    }

    table.insert(list, entry)

    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Transparency = 1
    part.Position = data.Pos
    part.Parent = workspace

    makeBillboard(entry, part)
end)

--------------------------------------------------------------------------
-- ===== Buff Tracker ==== --
--------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModifiersViewerAll"
screenGui.ResetOnSpawn = false
screenGui.Enabled = true
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Container"
frame.Size = UDim2.new(0, 500, 0, 350)
frame.Position = UDim2.new(0, 10, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -10, 0, 24)
title.Position = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Active Buffs (Timed Only)"
title.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "List"
scroll.Size = UDim2.new(1, -10, 1, -35)
scroll.Position = UDim2.new(0, 5, 0, 30)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 4
scroll.Parent = frame

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)
listLayout.Parent = scroll

local function formatSeconds(seconds: number): string
    seconds = math.max(0, math.floor(seconds + 0.5))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

local function makeLabel()
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 0, 18)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Text = ""
    label.Parent = scroll
    return label
end

local function updateLabel(buffName, info)
    local def = info.def
    local displayName = buffName
    if def and def.DisplayName then
        displayName = def.DisplayName
    elseif def and def.Name then
        displayName = def.Name
    end

    local text = "[" .. tostring(displayName) .. "]"

    if info.combo and info.combo > 1 then
        text = text .. "  x" .. tostring(info.combo)
    end

    local now = OsTime()
    local remaining = info.dur - (now - info.start)
    if remaining < 0 then remaining = 0 end

    text = text .. "  |  " .. formatSeconds(remaining)
    info.label.Text = text
end

local function removeBuff(buffName)
    local info = activeBuffs[buffName]
    if not info then return end
    if info.label then
        info.label:Destroy()
    end
    activeBuffs[buffName] = nil
end

local function addOrUpdateBuff(buffName, startTime, dur, combo)
    -- Only timed buffs with dur > 0 should be shown
    if not dur or dur <= 0 then
        removeBuff(buffName)
        return
    end

    local def = Buffs.Get(buffName)
    if not def or def.Hidden then
        return
    end

    if combo == nil then combo = 1 end

    local info = activeBuffs[buffName]
    if not info then
        local label = makeLabel()
        info = {
            label = label,
            start = startTime or OsTime(),
            dur = dur,
            combo = combo,
            def = def,
        }
        activeBuffs[buffName] = info
    else
        info.start = startTime or info.start or OsTime()
        info.dur = dur or info.dur
        info.combo = combo or info.combo
        info.def = def
    end

    updateLabel(buffName, info)
end

Events.ClientListen("ServerBuffEvent", function(action, buffName, startTime, dur, combo, mods)

    if not BotState.showDebugInfo then 
        return
    end

    if not buffName then
        return
    end

    if action == "Apply" or action == "Continue" then
        addOrUpdateBuff(buffName, startTime, dur, combo)

    elseif action == "ChangeCombo" then
        local info = activeBuffs[buffName]
        if info then
            info.combo = combo or info.combo
            if info.dur and info.dur > 0 then
                info.start = OsTime()
                updateLabel(buffName, info)
            end
        end

    elseif action == "Remove" then
        removeBuff(buffName)

    elseif action == "RemoveAll" then
        for name in pairs(activeBuffs) do
            removeBuff(name)
        end

    elseif action == "RemoveLostOnDeath" then
        local toRemove = {}
        for name, info in pairs(activeBuffs) do
            local def = info.def or Buffs.Get(name)
            if def and def.LostOnDeath then
                table.insert(toRemove, name)
            end
        end
        for _, name in ipairs(toRemove) do
            removeBuff(name)
        end

    elseif action == "ChangeStartTime" then
        local info = activeBuffs[buffName]
        if info and info.dur and info.dur > 0 then
            info.start = startTime or OsTime()
            updateLabel(buffName, info)
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do 
        if not BotState.showDebugInfo then
            local gui: ScreenGui = playerGui:FindFirstChild("ModifiersViewerAll") :: ScreenGui
            local container: Frame = gui:FindFirstChild("Container") :: Frame
            container.Visible = false
            continue
        end

        if playerGui:FindFirstChild("ModifiersViewerAll") then 
            local gui: ScreenGui = playerGui:FindFirstChild("ModifiersViewerAll") :: ScreenGui
            local container: Frame = gui:FindFirstChild("Container") :: Frame
            container.Visible = true
        end

        local now = OsTime()
        if now - lastUpdate < UPDATE_DT then
            continue
        end
        lastUpdate = now
    
        local toRemove = {}
    
        for buffName, info in pairs(activeBuffs) do
            local remaining = info.dur - (now - info.start)
            if remaining <= 0 then
                table.insert(toRemove, buffName)
            else
                updateLabel(buffName, info)
            end
        end
    
        for _, name in ipairs(toRemove) do
            removeBuff(name)
        end
    end
end)

return DebugService