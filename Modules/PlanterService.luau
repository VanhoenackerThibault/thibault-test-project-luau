local BotState = _G.State :: any

local players: Players = game:GetService("Players")
local localPlayer: Player = players.LocalPlayer
local activePlanters: { any } = BotState.activePlanters

local replicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local events: ModuleScript = replicatedStorage:WaitForChild("Events") :: ModuleScript
local planterCollectEvent: RemoteEvent = events:WaitForChild("PlanterModelCollect") :: RemoteEvent
local PlayerActivesCommand: RemoteEvent = events:WaitForChild("PlayerActivesCommand"):: RemoteEvent

local PlanterService = {}

local panterInfoMap = {
    ["Paper"] = {
        Fields = nil,
        NectarBoosts = {
            Comforting  = 0.75,
            Motivating  = 0.75,
            Satisfying  = 0.75,
            Refreshing  = 0.75,
            Invigorating = 0.75,
        },
    },
    ["Ticket"] = {
        Fields = nil,
        NectarBoosts = {
            Comforting  = 2,
            Motivating  = 2,
            Satisfying  = 2,
            Refreshing  = 2,
            Invigorating = 2,
        },
    },
    ["Sticker"] = {
        Fields = nil,
        NectarBoosts = {
            Motivating = 2,
            Satisfying = 2,
            Comforting = 2,
            Invigorating = 2,
            Refreshing = 2
        },
    },
    ["Festive"] = {
        Fields = nil,
        NectarBoosts = {
            Comforting  = 3,
            Motivating  = 3,
            Satisfying  = 3,
            Refreshing  = 3,
            Invigorating = 3,
        },
    },
    ["Plastic"] = {
        Fields = nil,
        NectarBoosts = {
            Comforting  = 1,
            Motivating  = 1,
            Satisfying  = 1,
            Refreshing  = 1,
            Invigorating = 1,
        },
    },
    ["Candy"] = {
        Fields = {"Strawberry Field", "Pineapple Patch", "Coconut Field"},
        NectarBoosts = {
            Motivating  = 1.2,
        },
    },
    ["Red Clay"] = {
        Fields = {"Pepper Patch", "Pumpkin Patch"},
        NectarBoosts = {
            Invigorating = 1.2,
            Satisfying  = 1.2,
        },
    },
    ["Blue Clay"] = {
        Fields = {"Blue Flower Field", "Pine Tree Forest"},
        NectarBoosts = {
            Refreshing = 1.2,
            Comforting  = 1.2,
        },
    },
    ["Tacky"] = {
        Fields = {"Sunflower Field", "Dandelion Field"},
        NectarBoosts = {
            Satisfying = 1.25,
            Comforting  = 1.25,
        },
    },
    ["Pesticide"] = {
        Fields = {"Spider Field", "Sunflower Field", "Pineapple Patch", "Pumpkin Patch"},
        NectarBoosts = {
            Motivating = 1.25,
            Satisfying  = 1.25,
        },
    },
    ["Heat-Treated"] = {
        Fields = {"Pepper Patch", "Rose Field"},
        NectarBoosts = {
            Motivating = 1.3,
            Invigorating  = 1.3,
        },
    },
    ["Hydroponic"] = {
        Fields = {"Blue Flower Field", "Pine Tree Forest"},
        NectarBoosts = {
            Refreshing = 1.3,
            Comforting  = 1.3,
        },
    },
    ["Petal"] = {
        Fields = {"Pineapple Patch", "Dandelion Field"},
        NectarBoosts = {
            Satisfying = 1.5,
            Comforting  = 1.5,
        },
    },
    ["Plenty"] = {
        Fields = {"Pepper Patch", "Stump Field", "Mountain Top Field", "Coconut Field"},
        NectarBoosts = {
            Comforting  = 1.5,
            Motivating  = 1.5,
            Satisfying  = 1.5,
            Refreshing  = 1.5,
            Invigorating = 1.5,
        },
    },
}

local fieldsToNactar = {
    Comforting  = {"Dandelion Field", "Bamboo Field", "Pine Tree Forest"},
    Motivating  = {"Mushroom Field", "Spider Field", "Stump Field", "Rose Field"},
    Satisfying  = {"Sunflower Field", "Pineapple Patch", "Pumpkin Patch"},
    Refreshing  = {"Blue Flower Field", "Strawberry Field", "Coconut Field"},
    Invigorating = {"Clover Field", "Cactus Field", "Mountain Top Field", "Pepper Patch"},
}


function PlanterService.Init(services)
    PlanterService.Services = services
end

function PlanterService._GetBestPlanter(Nectar: string): string?
    local allowedFields: { [string]: true } = {}
    local bestPlanterName: string? = nil
    local bestNectarBoost: number? = nil

    local nectarFields = fieldsToNactar[Nectar]
    if not nectarFields then
        return nil
    end

    -- Build a set of allowed fields for this nectar
    for _, field: string in ipairs(nectarFields) do
        if not BotState.blackListedFields[field] then
            allowedFields[field] = true
        end
    end

    -- If no allowed fields left, nothing to plant
    if next(allowedFields) == nil then
        return nil
    end

    -- Scan selected planters
    for _, planter: string in ipairs(BotState.selectedPlanters) do
        local planterInfo = panterInfoMap[planter]
        if not planterInfo then continue end

        local boost = planterInfo.NectarBoosts and planterInfo.NectarBoosts[Nectar]

        -- Skip if this planter doesn't boost this nectar at all
        if not boost then continue end
        
        local fields = planterInfo.Fields

        local matchesAllowedField = false

        -- If Fields is nil, treat as "global" planter: allowed anywhere
        if fields == nil then
            matchesAllowedField = true
        else
            -- Check if it can be placed in at least one allowed field
            for _, fieldName: string in ipairs(fields) do
                if allowedFields[fieldName] then
                    matchesAllowedField = true
                    break
                end
            end
        end

        if matchesAllowedField then
            if not bestNectarBoost or boost > bestNectarBoost then
                bestNectarBoost = boost
                bestPlanterName = planter
            end
        end
    end

    if bestPlanterName then
        print("[PlanterService] Best planter for", Nectar, "is", bestPlanterName, "with boost", bestNectarBoost)
    else
        print("[PlanterService] No suitable planter found for", Nectar)
    end

    return bestPlanterName
end

function PlanterService._CollectPlanter(position: Vector3, planterId: number)
    if not position then 
        warn("[PlanterService] collectPlanter was called without position")
        return 
    end

    PlanterService.Services.TweenService.TweenPlayer(position)

    task.wait(0.5)

    planterCollectEvent:FireServer(planterId)

    if not BotState.activePlanters[planterId] then 
        print("[PlanterService] Planter Collected")
    else
        warn("[PlanterService] Collecting planter failed")
    end
end

function PlanterService._CheckCollectEveryHour(): { any }
    local selectedPlanters = {}

    for _, planter in BotState.activePlanters do
        if (planter.guessedPlantTime + (BotState.collectEvery * 60)) <= tick() then 
            print("planter has stayed long enough, time to go")
            table.insert(selectedPlanters, planter)
        end
    end

    return selectedPlanters
end

function PlanterService._CheckGrowthPercent(): { any }
    local selectedPlanters = {}

    for _, planter in BotState.activePlanters do
        if planter.GrowthPercent >= (BotState.collectAtPercentage / 100) then 
            print("planter has grown enough, time to go")
            table.insert(selectedPlanters, planter)
        end
    end

    return selectedPlanters
end

function PlanterService.PlantPlanter(position: Vector3, planter: string)
    if not position then 
        warn("[PlanterService] PlantPlanter was called without position")
        return 
    end

    PlanterService.Services.TweenService.TweenPlayer(position)

    task.wait(0.5)

    PlayerActivesCommand:FireServer({Name = planter})

    print("[PlanterService] Planter Placed")
end

function PlanterService.PlanterTick()
    local collectPlanters

    if BotState.collectEveryEnabled then 
        collectPlanters = PlanterService._CheckCollectEveryHour()
    elseif BotState.collectAtPercentageEnabled then
        collectPlanters = PlanterService._CheckGrowthPercent()
    end

    if not collectPlanters then 
        warn("[PlanterService] collectPlanters = nil")
        return
    end

    if #collectPlanters == 0 then 
        warn("[PlanterService] No planters to collect")
        return
    end

    for _, planter in collectPlanters do 
        PlanterService._CollectPlanter(planter.Pos, planter.ActorID)
    end

    local nectars: { any } = BotState.playerData.Totals.Nectar



    return 
end


return PlanterService