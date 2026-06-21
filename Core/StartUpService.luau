local BotState = _G.State :: any
local StartUpService = {}

local Workspace: Workspace = game:GetService("Workspace")
local replicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local claimHiveEvent: RemoteEvent = replicatedStorage:WaitForChild("Events"):WaitForChild("ClaimHive") :: RemoteEvent
local honeycombsFolder: Folder = Workspace:WaitForChild("Honeycombs") :: Folder
local hives: { Instance  } = honeycombsFolder:GetChildren() :: { Instance  }
local localPlayer = game:GetService("Players").LocalPlayer

local MAX_TRIES: number = 6

function StartUpService.Init(services): nil
    -- 'services' is a table containing all other services
    StartUpService.Services = services

    return
end

local function GetHiveWithHighestId(): Model?
    hives = honeycombsFolder:GetChildren()
    local closestHive: Model = nil

    for _, hive: Instance in ipairs(hives) do

        if not hive:IsA("Model") then 
            continue
        end

        local ownerObject: ObjectValue? = hive:FindFirstChild("Owner") :: ObjectValue?
        local hiveId: IntValue? = hive:FindFirstChild("HiveID") :: IntValue?

        if ownerObject == nil or hiveId == nil then
            continue
        end

        if ownerObject.Value then continue end

        if not closestHive then 
            closestHive = hive
        else
            local highestIdValue: IntValue = closestHive:FindFirstChild("HiveID") :: IntValue

            if hiveId.Value > highestIdValue.Value then 
                closestHive = hive
            end
        end
    end

    return closestHive :: Model?
end

function StartUpService.ClaimHive(): nil
    BotState.claimedHive = false
    BotState.hive = nil

    local tries: number = 0

    while not BotState.claimedHive and tries < MAX_TRIES do
        tries += 1

        local closestHive: Model? = GetHiveWithHighestId()
        if closestHive == nil then
            warn(string.format("[StartUpService] No available hive found (attempt %d/%d)",tries,MAX_TRIES))
            task.wait(1)
            continue
        end

        local platformObject: ObjectValue? = closestHive:FindFirstChild("Platform") :: ObjectValue?
        if platformObject == nil or platformObject.Value == nil then
            warn(string.format("[StartUpService] Hive '%s' missing valid Platform ObjectValue (attempt %d/%d)",closestHive.Name,tries,MAX_TRIES))
            task.wait(1)
            continue
        end

        local platformModel: Model = platformObject.Value :: Model
        local platformPart: BasePart? = platformModel:FindFirstChild("Platform") :: BasePart?
        if platformPart == nil then
            warn(string.format("[StartUpService] Hive '%s' platform Model missing 'Platform' part (attempt %d/%d)",closestHive.Name,tries,MAX_TRIES))
            task.wait(1)
            continue
        end

        local targetPosition: Vector3 = platformPart.Position + Vector3.new(0, 5, 0)

        local services = StartUpService.Services
        if services == nil then
            warn("[StartUpService] Services not initialized; cannot tween to hive")
            return
        end

        print(string.format("[StartUpService] Attempting to claim hive '%s' at position %s (attempt %d/%d)",closestHive.Name,tostring(targetPosition),tries,MAX_TRIES))

        services.TweenService.TweenPlayer(targetPosition)

        task.wait(0.5)

        local currentBest: Model? = GetHiveWithHighestId()
        if currentBest ~= nil and currentBest ~= closestHive then
            warn(string.format("[StartUpService] Hive choice changed during tween (initial '%s', now '%s') (attempt %d/%d)",closestHive.Name,currentBest.Name,tries,MAX_TRIES))
            task.wait(1)
            continue
        end

        local hiveIdValue: IntValue? = closestHive:FindFirstChild("HiveID") :: IntValue?
        if hiveIdValue == nil then
            warn(string.format("[StartUpService] Hive '%s' missing HiveID IntValue (attempt %d/%d)",closestHive.Name,tries,MAX_TRIES))
            task.wait(1)
            continue
        end

        claimHiveEvent:FireServer(hiveIdValue.Value)

        task.wait(0.5)

        local hives: { Instance } = honeycombsFolder:GetChildren()

        for _, inst: Instance in ipairs(hives) do
            if not inst:IsA("Model") then
                continue
            end

            local hive: Model = inst
            local ownerStringValue: StringValue? = hive:FindFirstChild("Owner") :: StringValue?

            
            if ownerStringValue ~= nil and tostring(ownerStringValue.Value) == tostring(localPlayer.Name) then
                BotState.claimedHive = true
                BotState.hive = hive
                print(string.format("[StartUpService] Successfully claimed hive '%s' for player '%s' on attempt %d",hive.Name,localPlayer.Name,tries))
                return
            end
        end

        if not BotState.claimedHive then
            warn(string.format("[StartUpService] ClaimHive did not assign any hive to '%s' after server call (attempt %d/%d)",localPlayer.Name,tries,MAX_TRIES))
            task.wait(1)
        end
    end

    if not BotState.claimedHive then
        warn(string.format("[StartUpService] Failed to claim any hive for '%s' after %d attempts",localPlayer.Name,MAX_TRIES))
    end

    return
end

return StartUpService :: any
