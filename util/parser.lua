local parser = {}

local beastman_status_map = {
    [0] = 'Training',
    [1] = 'Advancing',
    [2] = 'Attacking',
    [3] = 'Retreating',
    [4] = 'Defending',
    [5] = 'Preparing',
}

local faction_definitions = {
    mamool = { name = 'Mamool Ja Savages' },
    trolls = { name = 'Troll Mercenaries' },
    llamia = { name = 'Undead Swarm' },
}

local function copy_table(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function status_string(id)
    if id == nil then
        return 'Unknown'
    end

    return beastman_status_map[id] or string.format('State %s', tostring(id))
end

function parser.parse(packet)
    if not packet then
        return nil, 'missing packet'
    end

    local ok, results = pcall(function()
        local _, _, mamool_level = packet:unpack('b2b2b4', 0xA0 + 1)
        local trolls_level, llamia_level = packet:unpack('b4b4', 0xA1 + 1)
        local mamool_status, trolls_status, llamia_status_part_1 = packet:unpack('b3b3b2', 0xA2 + 1)
        local llamia_status_part_2 = packet:unpack('b1', 0xA3 + 1)
        local llamia_status_raw = llamia_status_part_1 + llamia_status_part_2

        return {
            mamool = {
                status = status_string(mamool_status),
                status_id = mamool_status,
                level = mamool_level,
            },
            trolls = {
                status = status_string(trolls_status),
                status_id = trolls_status,
                level = trolls_level,
            },
            llamia = {
                status = status_string(llamia_status_raw),
                status_id = llamia_status_raw,
                level = llamia_level,
            },
        }
    end)

    if not ok then
        return nil, results
    end

    return results
end

function parser.factions()
    return copy_table(faction_definitions)
end

function parser.status_map()
    return copy_table(beastman_status_map)
end

return parser
