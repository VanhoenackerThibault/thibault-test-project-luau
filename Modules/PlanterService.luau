local BotState = _G.State :: any

local players: Players = game:GetService("Players")
local localPlayer: Player = players.LocalPlayer

local replicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local events: ModuleScript = replicatedStorage:WaitForChild("Events") :: ModuleScript
local planterCollectEvent: RemoteEvent = events:WaitForChild("PlanterModelCollect") :: RemoteEvent
local PlayerActivesCommand: RemoteEvent = events:WaitForChild("PlayerActivesCommand"):: RemoteEvent
local clientStatCache = require(game.ReplicatedStorage.ClientStatCache)

local PlanterService = {}

local planterInfoMap = {
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
        Fields = {"Pepper Patch", "Rose Field", "Mushroom Field", "Strawberry Field"},
        NectarBoosts = {
            Invigorating = 1.2,
            Satisfying  = 1.2,
        },
    },
    ["Blue Clay"] = {
        Fields = {"Blue Flower Field", "Pine Tree Forest", "Bamboo Field", "Stump Field"},
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
        Fields = {"Pepper Patch", "Rose Field", "Mushroom Field", "Strawberry Field"},
        NectarBoosts = {
            Motivating = 1.3,
            Invigorating  = 1.3,
        },
    },
    ["Hydroponic"] = {
        Fields = {"Blue Flower Field", "Pine Tree Forest", "Bamboo Field", "Stump Field"},
        NectarBoosts = {
            Refreshing = 1.3,
            Comforting  = 1.3,
        },
    },
    ["Petal"] = {
        Fields = {"Pineapple Patch", "Dandelion Field", "Coconut Field", "Sunflower Field", "Pumpkin Patch"},
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

local planterTypeToName = {
    ["Paper"] = "Paper Planter",
    ["Ticket"] = "Ticket Planter",
    ["Sticker"] = "Sticker Planter",
    ["Festive"] = "Festive Planter",
    ["Plastic"] = "Plastic Planter",
    ["Candy"] = "Candy Planter",
    ["Red Clay"] = "Red Clay Planter",
    ["Blue Clay"] = "Blue Clay Planter",
    ["Tacky"] = "Tacky Planter",
    ["Pesticide"] = "Pesticide Planter",
    ["Heat-Treated"] = "Heat-Treated Planter",
    ["Hydroponic"] = "Hydroponic Planter",
    ["Petal"] = "Petal Planter",
    ["Plenty"] = "The Planter Of Plenty"
}


function PlanterService.Init(services)
    PlanterService.Services = services
end

function PlanterService._GetBestPlanter(Nectar: string)
    local allowedFields: { [string]: true } = {}

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
    if not allowedFields then
        return nil
    end

    print(#BotState.selectedPlanters)

    print(BotState.selectedPlanters)

    for index, item in BotState.selectedPlanters do 
        print(index, item)
    end

    if #BotState.selectedPlanters == 0 then 
        warn("No planter selected")
    end

    local selectedPlanterAndField = {}

    -- Scan selected planters
    for _, planter: string in BotState.selectedPlanters do
        local planterInfo = planterInfoMap[planter]
        if not planterInfo then continue end

        local nectarBoost = planterInfo.NectarBoosts[Nectar]

        local fields = PlanterService.Services.FieldsService.FieldInfo

        for fieldName, _ in allowedFields do
            local position = nil
            local selectedPlanterAndFieldLength = #selectedPlanterAndField

            for _, field in fields do 
                if fieldName == field.Name then 
                    position = field.Position
                end
            end

            if not planterInfo.Fields then 
                table.insert(selectedPlanterAndField, {Planter = planter, NectarBoost = nectarBoost or 0, FieldName = fieldName, FieldLocation = position, PreferedField = true})
                continue
            end


            for _, planterField in planterInfo.Fields do 
                if fieldName == planterField then
                    table.insert(selectedPlanterAndField, {Planter = planter, NectarBoost = nectarBoost or 0, FieldName = fieldName, FieldLocation = position, PreferedField = true})
                end
            end

            if selectedPlanterAndFieldLength == #selectedPlanterAndField then
                table.insert(selectedPlanterAndField, {Planter = planter, NectarBoost = nectarBoost or 0, FieldName = fieldName, FieldLocation = position, PreferedField = false})
            end
        end
    end

    local bestPlanter = nil
    local bestPlanterFallBack = nil

    table.sort(selectedPlanterAndField, function(table1, table2)
        return table1.NectarBoost > table2.NectarBoost
    end)

    for _, info in ipairs(selectedPlanterAndField) do
        local planterUsed = false

        print("getting activeplanters")
        local activePlanters: { any } = BotState.activePlanters
        print("active planters length ", #activePlanters)

        for _, planterInfo in ipairs(activePlanters) do

            print(tostring(planterInfo.Type), tostring(info.Planter))

            if tostring(planterInfo.Type) == tostring(info.Planter) then
                print("Planter used already")
                planterUsed = true
                break
            end
        end

        if planterUsed then
            continue
        end

        if info.PreferedField then
            if not bestPlanter or bestPlanter.NectarBoost < info.NectarBoost then
                print(info.Planter, info.NectarBoost, info.PreferedField, "PREFERD")
                bestPlanter = info
            end
        else
            if not bestPlanterFallBack or bestPlanterFallBack.NectarBoost < info.NectarBoost then
                print(info.Planter, info.NectarBoost, info.PreferedField, "FALLBACK")
                bestPlanterFallBack = info
            end
        end
    end

    if bestPlanter then 
        print("returning prefered planter")
        return bestPlanter
    end

    if bestPlanterFallBack then 
        print("returning NOT Prefered planter")
        return bestPlanterFallBack
    end

    return nil
end

function PlanterService._CollectPlanter(position: Vector3, planterId: number)
    if not position then 
        warn("[PlanterService] collectPlanter was called without position")
        return 
    end

    PlanterService.Services.TweenService.TweenPlayer(position + Vector3.new(0, 10, 0))

    task.wait(0.5)

    planterCollectEvent:FireServer(planterId)

    for index, item in BotState.activePlanters do
        print(index, item)
    end

    BotState.activePlanters[planterId] = nil

    print("[PlanterService] Planter Collected")
end

function PlanterService._CheckCollectEveryHour(): { any }
    local selectedPlanters = {}

    for _, planter in pairs(BotState.activePlanters) do
        local collectAfter = planter.guessedPlantTime + (BotState.collectEvery * 60 * 60)
        print(collectAfter, tick())
        if collectAfter <= tick() then
            print("planter has stayed long enough, time to go")
            table.insert(selectedPlanters, planter)
        end
    end

    return selectedPlanters
end

function PlanterService._CheckGrowthPercent(): { any }
    local selectedPlanters = {}
    
    for _, planter in pairs(BotState.activePlanters) do
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

    PlanterService.Services.TweenService.TweenPlayer(position + Vector3.new(0, 10, 0))

    task.wait(0.5)
    print(planter)
    PlayerActivesCommand:FireServer({Name = planter})

    print("[PlanterService] Planter Placed")
end

function PlanterService.CanFarmPlanter(): boolean
    local collectPlanters

    if #BotState.activePlanters == 0 then 
        return true
    end
    
    if BotState.collectEveryEnabled then 
        collectPlanters = PlanterService._CheckCollectEveryHour()
    elseif BotState.collectAtPercentageEnabled then
        collectPlanters = PlanterService._CheckGrowthPercent()
    end

    if not collectPlanters then 
        return false
    end

    if #collectPlanters == 0 then 
        return false
    end

    return true
end

function PlanterService.PlanterTick()
    if BotState.gettingNectar then 
        return
    end

    for index, item in BotState.activePlanters do 
        for index2, item2 in item do 
            print(index2, item2)
        end
    end

    local collectPlanters

    if BotState.collectEveryEnabled then 
        collectPlanters = PlanterService._CheckCollectEveryHour()
    elseif BotState.collectAtPercentageEnabled then
        collectPlanters = PlanterService._CheckGrowthPercent()
    end

    if collectPlanters and #collectPlanters > 0 then 
        for _, planter in collectPlanters do 
            PlanterService._CollectPlanter(planter.Pos, planter.ActorID)
        end
    end

    local nectars = BotState.nactarTimers
    local settings = BotState.nectarSettings

    local selectedNectars = {}

    for nectar, info in settings do 
        if not info.enabled then 
            continue
        end

        local time = nectars[nectar] or 0

        if info.hours * 3600 > time then 
            table.insert(selectedNectars, nectar)
        end
    end

    if not selectedNectars or #selectedNectars == 0 then 
        warn("No selected Nectars")
        return
    end


    if not selectedNectars then 
        return
    end

    if #selectedNectars == 0 then 
        return
    end

    BotState.gettingNectar = true

    for _, item in selectedNectars do 
        local planterInfo = PlanterService._GetBestPlanter(item)
        
        PlanterService.PlantPlanter(planterInfo.FieldLocation, planterTypeToName[planterInfo.Planter])
    end

    BotState.gettingNectar = false

    return 
end


return PlanterService