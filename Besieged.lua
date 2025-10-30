_addon.name = 'Besieged'
_addon.author = 'Meliora, Xurion'
_addon.version = '1.0.0'
_addon.commands = { 'besieged', 'bs' }

---------------------------------------------------------------------------------------
-- CREDIT / ACKNOWLEDGEMENTS
-- Original addon by Xurion; refactored and expanded with the core behavior preserved.
-- https://github.com/xurion/ffxi-besieged
---------------------------------------------------------------------------------------

local packets = require('packets')
local Settings = require('util.settings')
local parser = require('util.parser')
local Tracker = require('util.tracker')
local Notifier = require('util.notifier')

local function add_to_chat(color, message)
    windower.add_to_chat(color or 7, message)
end

local Timer = {}
Timer.__index = Timer

function Timer.new()
    return setmetatable({ start_time = os.time() }, Timer)
end

function Timer:start()
    self.start_time = os.time()
end

function Timer:next()
    self.start_time = os.time()
end

function Timer:check()
    return os.time() - (self.start_time or os.time())
end

local settings = Settings.load()

local tracker = Tracker.new()
local notifier = Notifier.new(settings)
local timer = Timer.new()
local requesting = false
local last_snapshot = nil
local last_second = os.time()

local function debug_log(message)
    if settings.debug then
        windower.console.write('[Besieged] ' .. message)
    end
end

local function update_countdown()
    local remaining = math.max(0, math.floor(settings.interval - timer:check()))
    notifier:refresh_snapshot(last_snapshot, remaining, settings.debug)
end

local function can_request()
    local info = windower.ffxi.get_info()
    return info and info.logged_in
end

local function request_besieged_data()
    if requesting then
        return
    end

    if not can_request() then
        debug_log('Request blocked: not logged in')
        return
    end

    requesting = true
    debug_log('Requesting Besieged data from server')

    local packet = packets.new('outgoing', 0x05A, {})
    packets.inject(packet)
end

local function handle_snapshot(snapshot)
    if not snapshot then
        debug_log('Snapshot missing; ignoring')
        return
    end

    last_snapshot = snapshot
    update_countdown()

    local messages = tracker:evaluate(snapshot)
    if #messages > 0 then
        notifier:announce(messages)
    else
        debug_log('No status changes detected')
    end
end

local function handle_incoming_packet(packet)
    local snapshot, err = parser.parse(packet)
    if not snapshot then
        debug_log('Failed to parse packet: ' .. tostring(err))
        requesting = false
        return
    end

    timer:next()
    requesting = false
    snapshot.timestamp = os.time()
    handle_snapshot(snapshot)
end

local function handle_hud_toggle(flag)
    if flag == nil then
        flag = not settings.notifications.hud
    end
    settings.notifications.hud = flag and true or false
    Settings.save(settings)
    notifier:update_options(settings)
    add_to_chat(207, string.format('[Besieged] HUD %s.', flag and 'enabled' or 'disabled'))
    if last_snapshot then
        update_countdown()
    end
end

local function handle_debug_toggle(flag)
    if flag == nil then
        flag = not settings.debug
    end
    settings.debug = flag and true or false
    Settings.save(settings)
    add_to_chat(207, string.format('[Besieged] Debug mode %s.', flag and 'enabled' or 'disabled'))
end

local function show_status()
    if not last_snapshot then
        add_to_chat(207, '[Besieged] No data received yet.')
        return
    end

    local summary = tracker:summary(last_snapshot)
    add_to_chat(207, 'Besieged Status:')
    for _, line in ipairs(summary) do
        add_to_chat(207, '  ' .. line)
    end
end

local function process_command(command, args)
    if not command then
        return
    end

    command = tostring(command)
    local cmd = command:lower()

    if cmd == 'hud' then
        local arg = args[1] and tostring(args[1]):lower()
        local flag = arg == 'on' and true or (arg == 'off' and false or nil)
        handle_hud_toggle(flag)
    elseif cmd == 'debug' then
        local arg = args[1] and tostring(args[1]):lower()
        local flag = arg == 'on' and true or (arg == 'off' and false or nil)
        handle_debug_toggle(flag)
    elseif cmd == 'status' then
        show_status()
    elseif cmd == 'help' then
        add_to_chat(207, 'Besieged commands:')
        add_to_chat(207, '  //bs hud ON | OFF')
        add_to_chat(207, '  //bs debug ON | OFF]')
        add_to_chat(207, '  //bs status')
    end
end

windower.register_event('load', function()
    timer:start()
    notifier:update_options(settings)
    update_countdown()
    request_besieged_data()
    debug_log('Addon loaded; timer started.')
end)

windower.register_event('unload', function()
    notifier:destroy()
end)

windower.register_event('login', function()
    timer:next()
    requesting = false
    debug_log('Login detected; timer reset.')
end)

windower.register_event('logout', function()
    notifier:destroy()
    requesting = false
    last_snapshot = nil
end)

windower.register_event('prerender', function()
    local now = os.time()
    if now ~= last_second then
        last_second = now
        if timer:check() >= settings.interval then
            timer:next()
            request_besieged_data()
        else
            update_countdown()
        end
    end
end)

windower.register_event('incoming chunk', function(id, packet)
    if id == 0x05E then
        handle_incoming_packet(packet)
    end
end)

windower.register_event('addon command', function(command, ...)
    process_command(command, { ... })
end)
