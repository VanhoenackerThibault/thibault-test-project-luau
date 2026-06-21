local GuiUpdateHelper = {}

local BotState = _G.State :: any

local clientStatCache = require(game.ReplicatedStorage.ClientStatCache)
local runService = game:GetService("RunService")

local suffixes = {
    {1e33,  "Dc"},   -- Decillion
    {1e30,  "No"},   -- Nonillion
    {1e27,  "Oc"},   -- Octillion
    {1e24,  "Sp"},   -- Septillion
    {1e21,  "Sx"},   -- Sextillion
    {1e18,  "Qi"},   -- Quintillion
    {1e15,  "Qa"},   -- Quadrillion
    {1e12,  "T"},    -- Trillion
    {1e9,   "B"},    -- Billion
    {1e6,   "M"},    -- Million
    {1e3,   "K"},    -- Thousand
}

function GuiUpdateHelper.Init(services): nil
    -- 'services' is a table containing all other services
    GuiUpdateHelper.Services = services

    return
end

local function formatNumber(n: number): string
    local abs = math.abs(n)

    -- No suffix for small numbers
    if abs < 1000 then
        return tostring(n)
    end

    -- Find largest suffix that fits
    for _, data in ipairs(suffixes) do
        local value, suffix = data[1], data[2]
        if abs >= value then
            local short = n / value

            -- Keep up to 3 significant digits (12.3, 987, 1.23)
            local formatted: string

            if math.abs(short) >= 100 then
                formatted = string.format("%.0f", short)
            elseif math.abs(short) >= 10 then
                formatted = string.format("%.1f", short)
            else
                formatted = string.format("%.2f", short)
            end

            -- Strip trailing .0
            formatted = formatted:gsub("%.0$", "")

            return formatted .. suffix
        end
    end

    -- Fallback (shouldn't usually hit)
    return tostring(n)
end

function GuiUpdateHelper.FormatSeconds(seconds: number): string
    seconds = math.floor(seconds)  -- ignore fractional seconds for the format

    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60

    return string.format("%d:%02d:%02d", h, m, s)
end

function GuiUpdateHelper.ServerUpTime(paragraph): nil
    runService.Heartbeat:Connect(function()
        local serverStartTime: NumberValue = workspace:FindFirstChild("ServerTime") :: NumberValue
        paragraph:SetDesc(GuiUpdateHelper.FormatSeconds(serverStartTime.Value))
    end)

    return
end

function GuiUpdateHelper.ScriptUpTime(paragraph): nil
    local startTime: number = BotState.scriptStartTime
    
    runService.Heartbeat:Connect(function()
        local elapsed: number = tick() - startTime
        paragraph:SetDesc(GuiUpdateHelper.FormatSeconds(elapsed))
    end)

    return
end

function GuiUpdateHelper.HoneyMadeUpdateLoop(paragraph)
    runService.Heartbeat:Connect(function()
        local playerData: { [string]: any } = clientStatCache:Get()
        local honeyMade = playerData["Honey"] - BotState.startHoney
        
        paragraph:SetDesc(formatNumber(honeyMade))
    end)
end

function GuiUpdateHelper.HoneyPerHourUpdateLoop(paragraph)
    local startTime: number = tick()

    runService.Heartbeat:Connect(function()
        local playerData: { [string]: any } = clientStatCache:Get()
        local honeyMade = playerData["Honey"] - BotState.startHoney
        
        local elapsedSec = tick() - startTime
        if elapsedSec < 1 then
            paragraph:SetDesc(formatNumber(honeyMade))
            return
        end

        -- convert to hours and compute honey per hour
        local elapsedHours = elapsedSec / 3600
        local honeyPerHour = honeyMade / elapsedHours

        paragraph:SetDesc(formatNumber(honeyPerHour))
    end)
end

return GuiUpdateHelper