local config = require('config')

local Settings = {}
local current_settings

local defaults = {
    interval = 300,
    minimum_interval = 125,
    debug = false,
    notifications = {
        chat = true,
        chat_mode = 'add_to_chat',
        chat_color = 207,
        hud = true
    },
    hud_style = {
        pos = {
            x = 1120,
            y = 340
        },
        padding = 5,
        text = {
            size = 11,
            font = 'Consolas',
            alpha = 255,
            stroke = {
                width = 1
            }
        },
        bg = {
            alpha = 160,
            visible = true
        },
        flags = {
            bold = true
        }
    }
}

local function deep_assign(target, source)
    for key, value in pairs(source) do
        if type(value) == 'table' then
            if type(target[key]) ~= 'table' then
                target[key] = {}
            end
            deep_assign(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function ensure_defaults(settings)
    settings = settings or {}
    deep_assign(settings, defaults)
    settings.minimum_interval = settings.minimum_interval or defaults.minimum_interval
    settings.interval = math.max(settings.interval or defaults.interval, settings.minimum_interval)
    return settings
end

function Settings.defaults()
    return defaults
end

function Settings.load()
    local loaded = config.load(defaults)
    current_settings = ensure_defaults(loaded)
    return current_settings
end

function Settings.save(settings)
    local target = settings or current_settings
    if not target then
        return
    end
    local saver = target.save
    if type(saver) == 'function' then
        target:save()
        return
    end
    if config.save then
        config.save(target, defaults)
    end
end

function Settings.get()
    return current_settings
end

return Settings
