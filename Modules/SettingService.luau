local BotState = _G.State :: any

local RunService: RunService = game:GetService("RunService")
local Players: Players = game:GetService("Players")

local SettingService = {}

local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")

function SettingService.Init(services)
    SettingService.Services = services
end

local function SpeedController(): nil
    if not BotState.walkSpeedEnabled then
        return
    end

    if humanoid == nil then
        character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
        humanoid = character:FindFirstChildOfClass("Humanoid")
    end

    if humanoid == nil then
        return
    end

    humanoid.WalkSpeed = BotState.walkSpeed

    return
end

RunService.Heartbeat:Connect(SpeedController)

return SettingService