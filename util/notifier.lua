local texts = require('texts')

local Notifier = {}
Notifier.__index = Notifier

local function ensure_hud_settings(settings)
    settings = settings or {}
    return settings
end

local RESET_COLOR = '\\cr'
local STATUS_COLORS = {
    default = '\\cs(255,255,255)',
    Advancing = '\\cs(255,255,120)',
    Attacking = '\\cs(255,120,120)',
}

local function line_color(status)
    return STATUS_COLORS[status] or STATUS_COLORS.default
end

local FACTION_LABELS = {
    mamool = 'Mamool Ja',
    trolls = 'Troll Mercenaries',
    llamia = 'Undead Swarm',
}

local LABEL_WIDTH = 20
local STATUS_WIDTH = 12
local LEVEL_WIDTH = 12

local function format_line(label, status, level, color)
    local label_text = string.format('%s', label or '')
    local status_text = status or 'Unknown'
    local level_text = level and string.format('(Lv %d)', level) or '(Lv --)'
    return string.format(
        '%s%-' .. LABEL_WIDTH .. 's%' .. STATUS_WIDTH .. 's%' .. LEVEL_WIDTH .. 's%s',
        color or STATUS_COLORS.default,
        label_text,
        status_text,
        level_text,
        RESET_COLOR
    )
end

local function default_line(label)
    return format_line(label, 'waiting...', nil, STATUS_COLORS.default)
end

function Notifier.new(options)
    local self = setmetatable({}, Notifier)
    self.options = options
    self.hud = nil
    self.header_text = 'Besieged Status'
    self.hud_lines = {}
    self.key_order = { 'header', 'mamool_line', 'trolls_line', 'llamia_line', 'countdown_line', 'last_update' }

    if options.notifications.hud then
        self:create_hud()
    end

    return self
end

function Notifier:create_hud()
    if self.hud then
        return
    end

    local hud_settings = ensure_hud_settings(self.options.hud_style)
    self.hud_lines = {
        header = self:build_header_text(),
        mamool_line = default_line(FACTION_LABELS.mamool),
        trolls_line = default_line(FACTION_LABELS.trolls),
        llamia_line = default_line(FACTION_LABELS.llamia),
        countdown_line = '',
        last_update = '\nLast Update: --',
    }

    self.hud = texts.new(self:compose_text(), hud_settings)
    self.hud:show()
end

function Notifier:destroy()
    if self.hud then
        self.hud:hide()
        self.hud = nil
    end
end

function Notifier:update_options(options)
    self.options = options

    if self.options.notifications.hud then
        if not self.hud then
            self:create_hud()
        else
            self.hud:show()
            self.hud:text(self:compose_text())
        end
    elseif self.hud then
        self.hud:hide()
    end
end

local function build_header(messages)
    if not messages or #messages == 0 then
        return ''
    end

    return 'Besieged Update:\n' .. table.concat(messages, '\n')
end

local function send_chat(options, message)
    if options.notifications.chat_mode == 'logger' then
        log(message)
    else
        windower.add_to_chat(options.notifications.chat_color or 7, message)
    end
end

function Notifier:announce(messages)
    if not messages or #messages == 0 then
        return
    end

    if self.options.notifications.chat then
        send_chat(self.options, build_header(messages))
    end

    if self.hud then
        self:update_hud_field('last_update', '\nLast Update: Just now')
    end
end

local function relative_time_string(age_seconds)
    if not age_seconds or age_seconds < 0 then
        return '\nLast Update: --'
    end

    if age_seconds < 60 then
        return '\nLast Update: Just now'
    elseif age_seconds < 3600 then
        local minutes = math.floor(age_seconds / 60)
        return string.format('\nLast Update: %d minute%s ago', minutes, minutes ~= 1 and 's' or '')
    else
        local hours = math.floor(age_seconds / 3600)
        return string.format('\nLast Update: %d hour%s ago', hours, hours ~= 1 and 's' or '')
    end
end

function Notifier:refresh_status(report, countdown, show_countdown)
    if not self.hud then
        return
    end

    if not report then
        self.hud_lines.mamool_line = default_line(FACTION_LABELS.mamool)
        self.hud_lines.trolls_line = default_line(FACTION_LABELS.trolls)
        self.hud_lines.llamia_line = default_line(FACTION_LABELS.llamia)
        self.hud_lines.countdown_line = ''
        self.hud_lines.last_update = '\nLast Update: --'
        if self.hud then
            self.hud:text(self:compose_text())
        end
        return
    end

    local function build_line(label, status, level)
        local color = line_color(status)
        return format_line(label, status, level, color)
    end

    local update_fields = {
        mamool_line = build_line(FACTION_LABELS.mamool, report.mamool and report.mamool.status, report.mamool and report.mamool.level),
        trolls_line = build_line(FACTION_LABELS.trolls, report.trolls and report.trolls.status, report.trolls and report.trolls.level),
        llamia_line = build_line(FACTION_LABELS.llamia, report.llamia and report.llamia.status, report.llamia and report.llamia.level),
    }

    if show_countdown then
        update_fields.countdown_line = string.format('Next check in %ds', math.max(0, countdown or 0))
    else
        update_fields.countdown_line = ''
    end

    local age_seconds = 0
    if report.timestamp then
        age_seconds = os.time() - report.timestamp
    end

    self:update_hud(update_fields, age_seconds)
end

function Notifier:build_header_text()
    local header = self.header_text
    return header .. '\n'
end

function Notifier:compose_text()
    local lines = {}
    for _, key in ipairs(self.key_order) do
        local value = self.hud_lines[key]
        if value and value ~= '' then
            table.insert(lines, value)
        end
    end
    return table.concat(lines, '\n')
end

function Notifier:update_hud_field(key, value)
    self.hud_lines[key] = value
    if self.hud then
        self.hud:text(self:compose_text())
    end
end

function Notifier:build_lines(fields)
    for key, value in pairs(fields) do
        self.hud_lines[key] = value
    end
    self.hud_lines.header = self:build_header_text()
    return self.hud_lines
end

function Notifier:update_hud(update_fields, age_seconds)
    update_fields.last_update = relative_time_string(age_seconds)

    for key, value in pairs(update_fields) do
        self.hud_lines[key] = value
    end

    self.hud_lines.header = self:build_header_text()

    if self.hud then
        self.hud:text(self:compose_text())
    end
end

return Notifier
