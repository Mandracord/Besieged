local parser = require('util.parser')

local Tracker = {}
Tracker.__index = Tracker

local function normalize_status(entry, status_map)
    if type(entry) ~= 'table' then
        return 'Unknown'
    end

    local value = entry.status

    if value == nil and entry.status_id ~= nil then
        value = status_map[entry.status_id]
    end

    if type(value) == 'number' then
        value = status_map[value] or string.format('State %s', tostring(value))
    elseif value == nil then
        if entry.status_id ~= nil then
            value = status_map[entry.status_id] or string.format('State %s', tostring(entry.status_id))
        else
            value = 'Unknown'
        end
    end

    return value
end

local function clone_snapshot(snapshot, status_map)
    if not snapshot then
        return nil
    end

    local copy = {}
    for key, data in pairs(snapshot) do
        if type(data) == 'table' then
            copy[key] = {
                status = normalize_status(data, status_map),
                status_id = data.status_id,
                level = data.level,
            }
        end
    end
    return copy
end

function Tracker.new()
    local self = setmetatable({}, Tracker)
    self.last_snapshot = nil
    self.last_attacker = nil
    self.factions = parser.factions()
    self.status_text_map = parser.status_map()
    return self
end

function Tracker:evaluate(snapshot)
    local notifications = {}

    if not snapshot then
        return notifications
    end

    local previous = self.last_snapshot or {}

    for key, faction in pairs(self.factions) do
        local current = snapshot[key]
        local prior = previous[key]
        if type(prior) ~= 'table' then
            prior = nil
        end

        if type(current) == 'table' then
            current.status = normalize_status(current, self.status_text_map)

            if prior and prior.status == 'Attacking' and current.status ~= 'Attacking' then
                table.insert(notifications, 'The ' .. faction.name .. ' have retreated.')
            end

            if current.status == 'Attacking' then
                self.last_attacker = faction.name
                table.insert(notifications, string.format(
                    'Level %d %s are attacking Al Zahbi!',
                    current.level or 0,
                    faction.name
                ))
            elseif current.status == 'Advancing' then
                table.insert(notifications, string.format(
                    'Level %d %s are advancing towards Al Zahbi!',
                    current.level or 0,
                    faction.name
                ))
            end
        end
    end

    self.last_snapshot = clone_snapshot(snapshot, self.status_text_map)
    self.last_snapshot.timestamp = snapshot.timestamp
    return notifications
end

function Tracker:summary(snapshot)
    local result = {}

    if not snapshot then
        return result
    end

    for key, faction in pairs(self.factions) do
        local data = snapshot[key]
        if type(data) == 'table' then
            table.insert(result, string.format(
                '%s - %s (Lv %d)',
                faction.name,
                data.status or 'Unknown',
                data.level or 0
            ))
        end
    end

    return result
end

return Tracker
