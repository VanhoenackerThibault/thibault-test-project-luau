local BotState = _G.State :: any

local Players: Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventsModule: ModuleScript = ReplicatedStorage:WaitForChild("Events") :: ModuleScript
local BuffsModule: ModuleScript = ReplicatedStorage:FindFirstChild("Buffs") :: ModuleScript
local OstimeModule: ModuleScript = ReplicatedStorage:FindFirstChild("OsTime") :: ModuleScript
local LocalFXEvent: RemoteEvent = EventsModule:WaitForChild("LocalFX") :: RemoteEvent
local PlanterTypesModule: ModuleScript = ReplicatedStorage:WaitForChild("PlanterTypes") :: ModuleScript
local LocalPlantersModule: ModuleScript = ReplicatedStorage:WaitForChild("LocalPlanters") :: ModuleScript
local PlanterTypes = require(PlanterTypesModule)
local LocalPlanters = require(LocalPlantersModule)
local Buffs = require(BuffsModule)
local Events = require(EventsModule)
local OsTime = require(OstimeModule)

local planterInfo = debug.getupvalue(LocalPlanters.UpdatePlanter, 1)
local TrackerService = {}

function TrackerService.Init(services)
    TrackerService.Services = services
end

local function removeBuff(buffName)
    BotState.activeBuffs[buffName] = nil
end

local function addOrUpdateBuff(buffName, startTime, dur, combo)
    -- Only timed buffs with dur > 0 should be shown
    if not dur or dur <= 0 then
        removeBuff(buffName)
        return
    end

    local def = Buffs.Get(buffName)
    if not def or def.Hidden then

        for index, item in def do 
            print(index, item)
        end

        return
    end

    if not combo then
        combo = 1 
    end

    local info = BotState.activeBuffs[buffName]

    if not info then
        info = {
            start = startTime,
            dur = dur,
            combo = combo,
            def = def,
        }
        BotState.activeBuffs[buffName] = info
    else
        info.start = startTime
        info.dur = dur
        info.combo = combo
        info.def = def
    end
end

LocalFXEvent.OnClientEvent:Connect(function(effectName: string, data: {Action: string, Pos: Vector3, ID: number, FEID: number, Player: Player})
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

    if not BotState.preciseChains[feid] then
        BotState.preciseChains[feid] = {}
    end

    local list = BotState.preciseChains[feid]

    -- new entry for this FEID chain
    local entry: { FEID: number, ID: number, Index: number, Pos: Vector3 } = {
        Pos = data.Pos,
        Index = #list + 1,
        ID = id,
        FEID = feid,
    }


    table.insert(list, entry)

    task.delay(4.5, function()
        BotState.preciseChains[feid] = nil
    end)
end)

Events.ClientListen("ServerBuffEvent", function(action: string, buffName: string, startTime: number?, dur: number?, combo: number?, mods: { any }?)
    if not buffName then
        return
    end

    if action == "Apply" or action == "Continue" then
        addOrUpdateBuff(buffName, startTime, dur, combo)

    elseif action == "ChangeCombo" then

        local info = BotState.activeBuffs[buffName]

        if info then

            info.combo = combo
            if info.dur and info.dur > 0 then
                info.start = OsTime()
            end
        end

    elseif action == "Remove" then
        removeBuff(buffName)
    elseif action == "RemoveAll" then
        for name in pairs(BotState.activeBuffs) do
            removeBuff(name)
        end

    elseif action == "RemoveLostOnDeath" then
        local toRemove = {}

        for name, info in pairs(BotState.activeBuffs) do
            local def = info.def or Buffs.Get(name)

            if def and def.LostOnDeath then
                table.insert(toRemove, name)
            end
        end

        for _, name in ipairs(toRemove) do
            removeBuff(name)
        end

    elseif action == "ChangeStartTime" then
        local info = BotState.activeBuffs[buffName]

        if info and info.dur and info.dur > 0 then
            info.start = startTime
        end

    end
end)

local function ensureGuessedPlantTime(actorId)
	if not planterInfo then return end
	local info = planterInfo[actorId]
	if not info or not info.Active or info.Owner ~= localPlayer then return end

	local def = PlanterTypes.Get(info.Type)
	if not def or not def.MaxGrowth or not info.GrowthPercent then return end

	planterInfo[actorId].guessedPlantTime = OsTime() - (info.GrowthPercent * def.MaxGrowth)
end

task.spawn(function()
	while task.wait(0.1) do
		if not planterInfo then
            continue
		end
        
        for actorId, info in pairs(planterInfo) do
            if not info.Active or info.Owner ~= localPlayer then
                continue
            end

            for activeActorId, activeInfo in BotState.activePlanters do 
                if not planterInfo[activeActorId] then 
                    BotState.activePlanters[activeActorId] = nil
                end
            end
        
            ensureGuessedPlantTime(actorId)
            BotState.activePlanters[actorId] = info
        end
	end
end)

task.spawn(function()
    while task.wait(0.1) do 
        local now = OsTime()
        local toRemove = {}

        for buffName, info in pairs(BotState.activeBuffs) do
            if info.start and info.dur then
                local remaining = info.dur - (now - info.start)
                info.remaining = remaining 
        
                if remaining <= 0 then
                    table.insert(toRemove, buffName)
                end
            end
        end
    
        for _, name in ipairs(toRemove) do
            removeBuff(name)
        end
    end
end)

return TrackerService :: any