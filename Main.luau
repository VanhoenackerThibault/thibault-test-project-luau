local BotState = loadstring(game:HttpGet("https://raw.githubusercontent.com/VanhoenackerThibault/thibault-test-project-luau/refs/heads/main/Core/BotState.luau"))()

_G.State = BotState

if not BotState.loadedScript then
    local clientStatCache = require(game.ReplicatedStorage.ClientStatCache)
    local playerData: { [string]: any } = clientStatCache:Get()

    BotState.playerData = playerData
    BotState.startHoney = playerData["Honey"]
    BotState.scriptStartTime = tick()

    BotState.loadedScript = true
else
    print("============== script has been run before ====================")
end

-- ========== 2. LOAD UI & INITIALIZER ========== --
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Initializer = loadstring(game:HttpGet("https://raw.githubusercontent.com/VanhoenackerThibault/thibault-test-project-luau/refs/heads/main/Helpers/Initializer.luau"))()

-- ========== 3. INIT SERVICES ========== --

local services: { [string]: any } = Initializer.LoadServices()

local TweenService = services.TweenService
local StartUpService = services.StartUpService
local FieldsService = services.FieldsService
local SettingService = services.SettingService
local FarmService = services.FarmService
local BrainService = services.Brain
local GuiUpdateHelper = services.GuiUpdateHelper

-- ========== 4. PLAYER VARIABLES ========== --

local Players: Players = game:GetService("Players")
local plr: Player = Players.LocalPlayer
local char: Model = plr.Character or plr.CharacterAdded:Wait()
local VirtualUser = game:GetService("VirtualUser")
local httpService = game:GetService("HttpService")

-- ========== 6. Claim Hive ========== --
if not BotState.claimedHive then
    print("hive not claimed yet")
    services.StartUpService.ClaimHive()
end

-- ========== 6. UI WINDOW ========== --

local Window = WindUI:CreateWindow({
    Title = "twooto hub",
    Icon = "door-open",
    Author = "by twooto",
})

local Home = Window:Tab({
    Title = "Home",
    Icon = "bird",
    Locked = false,
})

local Farming = Window:Tab({
    Title = "Farming",
    Icon = "bird",
    Locked = false,
})

local Planters = Window:Tab({
    Title = "Planters",
    Icon = "bird",
    Locked = false,
})

local Settings = Window:Tab({
    Title = "Settings",
    Icon = "gear",
    Locked = false,
})

Home:Select()

Home:Toggle({
    Title = "Stop all",
    Desc = "Stops script",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        print("Script stopped: " .. tostring(state))
        BotState.scriptStopped = state
        return
    end,
})

local serverStartTimeParagraph = Home:Paragraph({
    Title = "Server Uptime",
    Desc = "0:0:0"
})

local scriptStartTime = Home:Paragraph({
    Title = "Script Uptime",
    Desc = "0:0:0"
})

local honeyMadeParagraph = Home:Paragraph({
    Title = "Honey made",
    Desc = BotState.startHoney
})

local honeyPerHourParagraph = Home:Paragraph({
    Title = "Honey Per Hour",
    Desc = "0"
})

Home:Toggle({
    Title = "Show debug info",
    Desc = "start showing debug info",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        print("showDebugInfo: " .. tostring(state))
        BotState.showDebugInfo = state
        return
    end,
})

GuiUpdateHelper.ServerUpTime(serverStartTimeParagraph)
GuiUpdateHelper.ScriptUpTime(scriptStartTime)
GuiUpdateHelper.HoneyMadeUpdateLoop(honeyMadeParagraph)
GuiUpdateHelper.HoneyPerHourUpdateLoop(honeyPerHourParagraph)

-- ========== 7. FARMING TAB ========== --

Farming:Dropdown({
    Title = "Field",
    Desc = "Select a field to farm at",
    Values = FieldsService.FieldDropdownValues,
    Value = "None",
    Callback = function(option: any): nil
        local title: string = tostring(option.Title)
        print("Field selected: " .. title)
        BotState.selectedField = title
        FieldsService.onCurrentZoneChanged()
        return
    end,
})

Farming:Toggle({
    Title = "Auto Farm",
    Desc = "Start auto farm",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        print("Auto Farm: " .. tostring(state))
        BotState.autoFarmEnabled = state
        return
    end,
})

Farming:Toggle({
    Title = "Grow scorching",
    Desc = "Auto grow scorching stars",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        print("Auto Farm: " .. tostring(state))
        -- BotState.autoFarmEnabled = state
        return
    end,
})

Farming:Slider({
    Title = "Minimum scorching boost",
    Desc = "whats the minimum boost the script should go for",
    
    Step = 1,
    Value = {
        Min = 10,
        Max = 250,
        Default = 100,
    },
    Callback = function(value)
        print(value)
    end
})

Farming:Toggle({
    Title = "Farm precise",
    Desc = "Auto farm precise, > 10 precision -> get full chains, < 10 precision and < 20 sec -> get marks else refresh",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        print("Auto Precision: " .. tostring(state))
        BotState.farmPrecision = state
        return
    end,
})

-- ========== 8. SETTINGS TAB ========== --

Settings:Slider({
    Title = "Walk Speed",
    Desc = "Adjust your walk speed",
    Step = 1,
    Value = {
        Min = 27,
        Max = 90,
        Default = 27,
    },
    Callback = function(value: number): nil
        BotState.walkSpeed = value
        if BotState.walkSpeedEnabled then
            SettingService.ChangeWalkspeed(char)
        end
        return
    end,
})

Settings:Toggle({
    Title = "Speed Hack",
    Desc = "Enable custom walk speed",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        print("Speed Hack: " .. tostring(state))
        BotState.walkSpeedEnabled = state
        SettingService.ChangeWalkspeed(char)
        return
    end,
})

Settings:Slider({
    Title = "Tween Speed",
    Desc = "Adjust your tween speed",
    Step = 1,
    Value = {
        Min = 1,
        Max = 40,
        Default = 23,
    },
    Callback = function(value: number): nil
        BotState.tweenSpeed = value * 3
        return
    end,
})

Settings:Slider({
    Title = "Convert Percentage",
    Desc = "Capacity percentage to convert at",
    Step = 1,
    Value = {
        Min = 1,
        Max = 100,
        Default = 100,
    },
    Callback = function(value: number): nil
        BotState.convertPercentage = value
        return
    end,
})

Settings:Toggle({
    Title = "Convert Balloon",
    Desc = "Makes script convert balloon",
    Icon = "bird",
    Type = "Checkbox",
    Value = true,
    Callback = function(state: boolean): nil
        BotState.convertBalloon = state
        return
    end,
})

Settings:Slider({
    Title = "Wait Till Convert",
    Desc = "Waits X secconds of full backpack to convert",
    Step = 1,
    Value = {
        Min = 0,
        Max = 120,
        Default = 0,
    },
    Callback = function(value: number): nil
        BotState.waitConvertTime = value
        return
    end,
})

Planters:Toggle({
    Title = "Auto Planter",
    Desc = "Auto plant/harvest planters",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        BotState.autoPlanter = state
        return
    end,
})

Planters:Dropdown({
    Title = "BlackListed Fields",
    Desc = "Select a field where script cant place planters",
    Values = FieldsService.FieldDropdownValues,
    Multi = true,
    Value = "None",
    Callback = function(option: any): nil
        BotState.blackListedFields = httpService:JSONEncode(option)
        print(httpService:JSONEncode(option))
        return
    end,
})

Planters:Dropdown({
    Title = "Planters",
    Desc = "Select allowed planters",
    Values = {
        "Paper",
        "Ticket",
        "Sticker",
        "Festive",
        "Plastic",
        "Candy",
        "Red Clay",
        "Blue Clay",
        "Tacky",
        "Pesticide",
        "Heat-Treated",
        "Hydroponic",
        "Petal",
        "Plenty"
    },
    Value = { "Plastic" },
    Multi = true,
    Callback = function(option) 
        BotState.selectedPlanters = httpService:JSONEncode(option)
    end
})

Planters:Dropdown({
    Title = "configs",
    Desc = "Select config",
    Values = {
        "Custom",
        "Red",
        "Blue",
        "White",
    },
    Value = { "Custom" },
    Multi = false,
    Callback = function(option) 
        -- option is a table: { "Category A", "Category B" }
        print("Categories selected: " .. httpService:JSONEncode(option)) 
    end
})

Planters:Slider({
    Title = "Alowed planters",
    Desc = "The amount of planters the script is allowed to plant",
    Step = 1,
    Value = {
        Min = 1,
        Max = 3,
        Default = 3,
    },
    Callback = function(value: number): nil
        BotState.allowedPlanters = value
        return
    end,
})

Planters:Toggle({
    Title = "Collect every time",
    Desc = "collect every time",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        BotState.collectEveryEnabled = state
        return
    end,
})

Planters:Slider({
    Title = "Collect every X Min",
    Desc = "Collect planters every X Min",
    Step = 1,
    Value = {
        Min = 1,
        Max = 300,
        Default = 120,
    },
    Callback = function(value: number): nil
        BotState.collectEvery = value
        return
    end,
})

Planters:Toggle({
    Title = "Collect at Percentage",
    Desc = "collect every hour",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state: boolean): nil
        BotState.collectAtPercentageEnabled = state
        return
    end,
})

Planters:Slider({
    Title = "Collect every X hours",
    Desc = "Collect planters every X hours",
    Step = 1,
    Value = {
        Min = 1,
        Max = 100,
        Default = 100,
    },
    Callback = function(value: number): nil
        BotState.collectAtPercentage = value
        return
    end,
})

--------------------------------------------------
-- Invigorating
--------------------------------------------------

Planters:Toggle({
    Title = "Farm Invigorating",
    Desc = "Farm Invigorating",
    Icon = "bird",
    Type = "Checkbox",
    Value = true,
    Callback = function(state: boolean): nil
        BotState.nectarSettings.Invigorating.enabled = state
        return
    end,
})

Planters:Slider({
    Title = "Min Hours",
    Desc = "Minimum amount of hours",
    Step = 1,
    Value = {
        Min = 1,
        Max = 24,
        Default = 0,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Invigorating.hours = value
        return
    end,
})

Planters:Slider({
    Title = "Priority",
    Desc = "Nectar priority (The higher the higher the priority)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 5,
        Default = 1,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Invigorating.priority = value
        return
    end,
})

--------------------------------------------------
-- Refreshing
--------------------------------------------------

Planters:Toggle({
    Title = "Farm Refreshing",
    Desc = "Farm Refreshing",
    Icon = "bird",
    Type = "Checkbox",
    Value = true,
    Callback = function(state: boolean): nil
        BotState.nectarSettings.Refreshing.enabled = state
        return
    end,
})

Planters:Slider({
    Title = "Min Hours",
    Desc = "Minimum amount of hours",
    Step = 1,
    Value = {
        Min = 1,
        Max = 24,
        Default = 0,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Refreshing.hours = value
        return
    end,
})

Planters:Slider({
    Title = "Priority",
    Desc = "Nectar priority (The higher the higher the priority)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 5,
        Default = 1,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Refreshing.priority = value
        return
    end,
})

--------------------------------------------------
-- Satisfying
--------------------------------------------------

Planters:Toggle({
    Title = "Farm Satisfying",
    Desc = "Farm Satisfying",
    Icon = "bird",
    Type = "Checkbox",
    Value = true,
    Callback = function(state: boolean): nil
        BotState.nectarSettings.Satisfying.enabled = state
        return
    end,
})

Planters:Slider({
    Title = "Min Hours",
    Desc = "Minimum amount of hours",
    Step = 1,
    Value = {
        Min = 1,
        Max = 24,
        Default = 0,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Satisfying.hours = value
        return
    end,
})

Planters:Slider({
    Title = "Priority",
    Desc = "Nectar priority (The higher the higher the priority)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 5,
        Default = 1,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Satisfying.priority = value
        return
    end,
})

--------------------------------------------------
-- Motivating
--------------------------------------------------

Planters:Toggle({
    Title = "Farm Motivating",
    Desc = "Farm Motivating",
    Icon = "bird",
    Type = "Checkbox",
    Value = true,
    Callback = function(state: boolean): nil
        BotState.nectarSettings.Motivating.enabled = state
        return
    end,
})

Planters:Slider({
    Title = "Min Hours",
    Desc = "Minimum amount of hours",
    Step = 1,
    Value = {
        Min = 1,
        Max = 24,
        Default = 0,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Motivating.hours = value
        return
    end,
})

Planters:Slider({
    Title = "Priority",
    Desc = "Nectar priority (The higher the higher the priority)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 5,
        Default = 1,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Motivating.priority = value
        return
    end,
})

--------------------------------------------------
-- Comforting
--------------------------------------------------

Planters:Toggle({
    Title = "Farm Comforting",
    Desc = "Farm Comforting",
    Icon = "bird",
    Type = "Checkbox",
    Value = true,
    Callback = function(state: boolean): nil
        BotState.nectarSettings.Comforting.enabled = state
        return
    end,
})

Planters:Slider({
    Title = "Min Hours",
    Desc = "Minimum amount of hours",
    Step = 1,
    Value = {
        Min = 1,
        Max = 24,
        Default = 0,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Comforting.hours = value
        return
    end,
})

Planters:Slider({
    Title = "Priority",
    Desc = "Nectar priority (The higher the higher the priority)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 5,
        Default = 1,
    },
    Callback = function(value: number): nil
        BotState.nectarSettings.Comforting.priority = value
        return
    end,
})



-- anti afk --
plr.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)