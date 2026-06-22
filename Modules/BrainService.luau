--!strict

local BotState = _G.State :: any

export type FarmServiceType = {
    FarmTick: () -> nil,
}

export type ConvertService = {
    ConvertPollen: () -> nil,
}

export type StartUpService = {
    ClaimHive: () -> nil,
}

export type PlanterService = {
    PlanterTick: () -> nil,
}

export type Services = {
    FarmService: FarmServiceType,
    ConvertService: ConvertService,
    StartUpService: StartUpService,
    PlanterService: PlanterService
}

export type BrainServiceType = {
    Services: Services?,
    Init: (services: Services) -> nil,
    Shutdown: () -> nil,
}

local BrainService: BrainServiceType = {
    Services = nil,
    Init = function(_services: Services) end,
    Shutdown = function() end,
}

local running: boolean = false

type Action = {
    Name: string,
    Priority: number,
    IsEnabled: () -> boolean,
    Run: () -> nil,
}

local actions: { Action } = {
    {
        Name = "Farm",
        Priority = 0,
        IsEnabled = function(): boolean
            return BotState.autoFarmEnabled
        end,
        Run = function(): nil
            if BrainService.Services and not BotState.farmRunning then
                BrainService.Services.FarmService.FarmTick()
            end

            return
        end,
    },
    {
        Name = "Convert",
        Priority = 10,
        IsEnabled = function(): boolean
            return BotState.converting
        end,
        Run = function(): nil
            if BrainService.Services then
                BrainService.Services.ConvertService.ConvertPollen()
            end

            return
        end,
    },
    {
        Name = "Planter",
        Priority = 100,
        IsEnabled = function(): boolean
            return BotState.autoPlanter
        end,
        Run = function(): nil
            if BrainService.Services then
                BrainService.Services.PlanterService.PlanterTick()
            end
    
            return
        end,
    },
    -- More actions (Mondo etc.) can go here
}

function BrainService.Init(services: Services): nil
    BrainService.Services = services

    

    -- Sort actions by Priority descending (highest first)
    table.sort(actions, function(a: Action, b: Action): boolean
        return a.Priority > b.Priority
    end)

    running = true
    task.spawn(function()
        while running do
            task.wait(0.1)

            if not BotState.claimedHive then 
                continue
            end

            if BotState.scriptStopped then 
                continue
            end

            for _, action: Action in ipairs(actions) do
                if action.IsEnabled() then
                    -- print("Running task: ", action.Name)
                    action.Run()
                    break
                end
            end
        end
    end)

    return
end

function BrainService.Shutdown(): nil
    running = false
    -- task.spawn loop will naturally exit on next iteration
    print("[BrainService] Shutdown requested")

    return
end

return BrainService