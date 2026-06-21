local BotState = _G.State :: any

local FieldsService = {}

local workspace: Workspace = game:GetService("Workspace")
local Players: Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer


type FieldInfoEntry = {
    Name: string,
    ShortName: string,
    Position: Vector3,
    Size: Vector3,
}

local fieldInfo: { FieldInfoEntry } = {}
local fieldDropdownValues: { { Title: string, order: number } } = {}

local skipFields: { [string]: boolean } = {
    ["Ant Field"] = true,
    ["Blue Brick Field"] = true,
    ["Hub Field"] = true,
    ["Mixed Brick Field"] = true,
    ["Red Brick Field"] = true,
    ["White Brick Field"] = true,
}


local function GetFields(): nil
    local zones: { Instance } = workspace:WaitForChild("FlowerZones"):GetChildren()

    for _, zone: Instance in ipairs(zones) do
        if not zone:IsA("Part") then
            continue
        end

        if skipFields[zone.Name] then
            continue
        end

        local id: NumberValue = zone:FindFirstChild("ID") :: NumberValue
        local shortName: StringValue = zone:FindFirstChild("ShortName") :: StringValue

        if id == nil or not id:IsA("NumberValue") then
            warn(string.format("[Fields] Field '%s' is missing a valid NumberValue 'ID'; skipping field",zone.Name))
            continue
        end

        if shortName == nil or not shortName:IsA("StringValue") then
            warn(string.format("[Fields] Field '%s' is missing a valid StringValue 'ShortName'; using full name as ShortName",zone.Name))
            continue
        end

        table.insert(fieldInfo, {Name = zone.Name, ShortName = shortName, Position = zone.Position, Size = zone.Size})
        table.insert(fieldDropdownValues, {Title = zone.Name, order = id.Value})
    end

    if #fieldInfo == 0 then
        warn("[Fields] GetFields completed but no valid fields were registered (check FlowerZones configuration)")
    end

    table.sort(fieldDropdownValues, function(firstField, secondField)
        return firstField.order < secondField.order
    end)

    return
end

function FieldsService.GetFieldPositionViaName(fieldName: string): Vector3?
    if fieldName == nil or fieldName == "" then
        warn("[Fields] GetFieldPositionViaName called with empty or nil field name")
        return nil
    end

    local position: Vector3? = nil

    for _, item in fieldInfo do 
        if item.Name == fieldName then 
            position = item.Position
        end
    end

    if position == nil then
        warn(string.format("[Fields] No position found for field name '%s'; ensure the field exists in FlowerZones",fieldName))
        return nil
    end

    return position
end

function FieldsService.onCurrentZoneChanged(): nil
    local fieldAttribute: string = localPlayer:GetAttribute("CurrentZone") :: string
    print("[FieldTracker] CurrentZone changed to:", tostring(fieldAttribute))

    local selectedField: string? = BotState.selectedField

    if tostring(fieldAttribute) == tostring(selectedField) then 
        BotState.inSelectedField = true
        return
    end

    BotState.inSelectedField = false

    return
end

function FieldsService.Init(services): nil
    -- 'services' is a table containing all other services
    FieldsService.Services = services
    GetFields()
    localPlayer:GetAttributeChangedSignal("CurrentZone"):Connect(FieldsService.onCurrentZoneChanged)

    return
end

FieldsService.FieldInfo = fieldInfo
FieldsService.FieldDropdownValues = fieldDropdownValues

return FieldsService :: any