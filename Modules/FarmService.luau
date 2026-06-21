local BotState = _G.State :: any

-- ==== Services ==== --
local PathfindingService: PathfindingService = game:GetService("PathfindingService")
local Players: Players = game:GetService("Players")
local Workspace: Workspace = game:GetService("Workspace")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local tokenMap = loadstring(game:HttpGet("https://raw.githubusercontent.com/VanhoenackerThibault/thibault-test-project-luau/refs/heads/main/Helpers/TokenMap.luau"))()

-- ==== variables ==== --
local localPlayer: Player = Players.LocalPlayer

local toolEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToolCollect") :: RemoteEvent
local activityEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlayerActivesCommand") :: RemoteEvent

local FarmService = {}
local collectedParts: { [Part]: boolean } = {}
local alreadyRegisteredPrecision: { FEID: number?, ID: number?, Index: number?, Pos: Vector3? } = {}


-- ==== Constants ==== --
local COLLECT_RADIUS: number = 75
local LIST_SIZE: number = 2

local PATHFINDING_PARAMS = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = false,
    AgentCanClimb = false,
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

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

----------------------------------------------------------------
-- Core FarmService API
----------------------------------------------------------------

function FarmService.Init(services): nil
    FarmService.Services = services
    return
end

function FarmService._TweenToField(): nil
    if BotState.selectedField == nil then
        warn("[FarmService] TweenToField called with no selected field")
        return
    end

    local fieldsService = FarmService.Services.FieldsService
    if fieldsService == nil then
        warn("[FarmService] Fields service not initialized; cannot tween to field")
        return
    end

    local fieldPosition: Vector3? = fieldsService.GetFieldPositionViaName(BotState.selectedField)
    if fieldPosition == nil then
        warn(string.format("[FarmService] Could not resolve position for field '%s'",tostring(BotState.selectedField)))
        return
    end

    local targetPosition: Vector3 = fieldPosition + Vector3.new(0, 10, 0)

    FarmService.Services.TweenService.TweenPlayer(targetPosition)
    task.wait(0.2)

    activityEvent:FireServer({ Name = "Sprinkler Builder" })

    BotState.inSelectedField = true

    return
end

function FarmService._moveToItem(item: Part?, position: Vector3?): nil
    local character: Model? = localPlayer.Character
    if character == nil then
        warn("[FarmService] _moveToItem called with no character")
        return
    end

    local hum: Humanoid? = character:FindFirstChildOfClass("Humanoid")
    local root: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?

    if hum == nil or root == nil then
        warn("[FarmService] _moveToItem missing Humanoid or HumanoidRootPart")
        return
    end

    local path: Path = PathfindingService:CreatePath(PATHFINDING_PARAMS)

    local ok: boolean, err: any = pcall(function()
        if not item and position then 
            path:ComputeAsync(root.Position, position)
        elseif item then
            path:ComputeAsync(root.Position, item.Position)
        end
    end)

    if not ok then
        warn("[FarmService] Pathfinding ComputeAsync threw an error:", err)
        return
    end

    local waypoints: { PathWaypoint } = path:GetWaypoints()
    if #waypoints == 0 then
        warn("[FarmService] Pathfinding returned zero waypoints; aborting move")
        return
    end

    for _, waypoint: PathWaypoint in ipairs(waypoints) do
        hum:MoveTo(waypoint.Position)

        local deadline: number = tick() + 2
        while tick() < deadline do
            task.wait()

            if BotState.converting == true then 
                break
            end

            if (root.Position - waypoint.Position).Magnitude < 5 then
                break
            end
        end
    end
    
    if item then 
        collectedParts[item] = true
    
        task.delay(10, function()
            collectedParts[item] = nil
        end)
    end

    return
end

function FarmService._GetPreciseTargets(): { Vector3 }
    if not BotState.farmPrecision then
        print(BotState.farmPrecision)
        return {}
    end

    local targets: {[number]: { FEID: number, ID: number, Index: number, Pos: Vector3 }} = BotState.preciseChains

    local posibleChains: { Vector3 } = {}

    for index, chain: {{ FEID: number, ID: number, Index: number, Pos: Vector3 }} in targets do
        if #chain < 3 then
            continue
        end

        for _, target: { FEID: number, ID: number, Index: number, Pos: Vector3 } in chain do

            if alreadyRegisteredPrecision[target] then
                warn("was aleady a target")
                continue
            end

            if BotState.activeBuffs.Precision then 
                local precision = BotState.activeBuffs.Precision

                if precision.combo < 10 and precision.remaining < 50 then
                    table.insert(posibleChains, target.Pos)
                    alreadyRegisteredPrecision[target] = true
                    print("Less then 10 precision, getting full chains")
                end
    
                if precision.combo == 10 and precision.remaining > 20 then
                    if target.Index == 3 then 
                        table.insert(posibleChains, target.Pos)
                        alreadyRegisteredPrecision[target] = true
                        print("10 precision, getting last target")
                    end
                end

                if precision.combo == 10 and precision.remaining < 20 then
                    table.insert(posibleChains, target.Pos)
                    alreadyRegisteredPrecision[target] = true
                    print("10 precision, need refresh")
                end
    
            else
                table.insert(posibleChains, target.Pos)
                alreadyRegisteredPrecision[target] = true
                print("Getting first precision")
            end

            task.delay(10, function()
                if alreadyRegisteredPrecision[target] then 
                    alreadyRegisteredPrecision[target] = nil
                end
            end)
        end
    end

    return posibleChains
end

function FarmService._GetTokensSortedByDistance(): {{ item: Part, dist: number }}
    local collectiblesFolder: Folder? = Workspace:FindFirstChild("Collectibles") :: Folder
    if collectiblesFolder == nil then
        warn("[FarmService] Collectibles folder not found in Workspace")
        return {}
    end

    local character: Model? = localPlayer.Character
    if character == nil then
        return {}
    end

    local root: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root == nil then
        return {}
    end

    local tokens: { { item: Part, dist: number } } = {}

    for _, itemInstance: Instance in ipairs(collectiblesFolder:GetChildren()) do
        if not itemInstance:IsA("Part") then
            continue
        end

        local item: Part = itemInstance

        if collectedParts[item] then 
            continue
        end

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
            local dist: number = (item.Position - root.Position).Magnitude
            if dist < COLLECT_RADIUS then
                table.insert(tokens, { item = item, dist = dist })
            end
        end
    end

    table.sort(tokens, function(a, b)
        return a.dist < b.dist
    end)

    local sorted: {{ item: Part, dist: number }} = {}
    local index: number = 0

    for _, entry in ipairs(tokens) do
        if index >= LIST_SIZE then
            break
        end

        table.insert(sorted, entry)
        index += 1
    end

    return sorted
end

function FarmService.farmPrecision(): nil
    local targets: { Vector3 } = FarmService._GetPreciseTargets()

    for _, position: Vector3 in pairs(targets) do 
        if not BotState.farmRunning or not BotState.autoFarmEnabled or BotState.scriptStopped then
            print("[FarmService] Farm task canceled")
            BotState.farmRunning = false
            return
        end

        if BotState.converting then
            warn("[FarmService] Cant collect targets, bussy converting")
            continue
        end

        FarmService._moveToItem(nil, position)
        toolEvent:FireServer()
    end

    return
end

function FarmService.FarmTick(): nil

    task.spawn(function()
        BotState.farmRunning = true

        while BotState.farmRunning or BotState.autoFarmEnabled do 
            task.wait()

            if not BotState.inSelectedField then
                warn("[FarmService] Player not in field")
                FarmService._TweenToField()
            end
            
            if BotState.tweening then
                break
            end

            
            FarmService.farmPrecision()
            
            local nearestTokens: {{ item: Part, dist: number }} = FarmService._GetTokensSortedByDistance()
            if #nearestTokens == 0 then
                continue
            end
            
            for _, itemdict: { item: Part, dist: number } in pairs(nearestTokens) do
                if not BotState.farmRunning or not BotState.autoFarmEnabled or BotState.scriptStopped then
                    print("[FarmService] Farm task canceled")
                    BotState.farmRunning = false
                    return
                end
    
                if BotState.converting then
                    warn("[FarmService] Cant collect tokens, bussy converting")
                    continue
                end
    
                FarmService._moveToItem(itemdict.item)
                toolEvent:FireServer()
            end
        end
    end)

    print("[FarmService] Fully exited FarmTick")
    return
end

return FarmService :: any