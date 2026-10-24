local Tween = require 'lib.tween'
local RunState = require 'src.states.run_state'

local infoTitleFont       = love.graphics.newFont(20)
local infoFont            = love.graphics.newFont(14)
local infoSmallFont       = love.graphics.newFont(12)
local infoFontHeight      = infoFont:getHeight()
local infoSmallFontHeight = infoSmallFont:getHeight()

local result_font = love.graphics.newFont(24)
local result_height = result_font:getHeight() + 10

local extraActionFont = love.graphics.newFont(18)

local BattleUI = Class{}

function BattleUI:init(state)
    self.state = state
    self.logX = 0
    self.logY = 0
    self.logW = 800
    self.logH = 0
    self.logOffset = 15
    self.logFont = love.graphics.newFont(22)
    self.logBackgroundColor = {1,1,1,0.90}
    self.logBorderColor = {0.3,0.3,0.3,0.95}
    self.logTextColor = {0.25,0.25,0.25,1}
    self.rewards_w = 220
    self.rewards_h = result_height
    self.rewards_tween = nil
    self.rewards_print_progress = 0
    self.show_rewards_items = false
    self.result_text = ""
end

function BattleUI:reset()
    self.rewards_tween = nil
    self.rewards_print_progress = 0
    self.show_rewards_items = false
end

function BattleUI:showResult(text)
    self.result_text = text
end

function BattleUI:updateExtraActionButton(state)
    if state.state ~= 'battle' then return end
    if state.paused then return end
    if state._extra_action_available <= 0 then return end
    if state.phase ~= 'idle' then return end

    local actor = state:current_actor()
    if not actor or not actor.is_player then return end

    UI.setStyle({
        draw_border      = true,
        border_color     = { 0, 0, 0, 1 },
        background_color = { 0.65, 0.55, 0.25, 1 },
        corner_radius    = 8,
    })
    UI.setFont(extraActionFont)
    UI.nextPosition("BOTTOMRIGHT", "root")

    if UI.button("extra_action_btn", -15, -15, 160, 100,
        "Use Extra Action", "BOTTOMRIGHT") then
        state:useExtraAction()
    end
end

function BattleUI:updatePrepare(dt)
    -- отрисовка "Prepare to fight!"
    UI.nextPosition("TOP", "root")
    UI.text(3, 43, "Prepare to fight!", "TOP", {0,0,0,1}, love.graphics.newFont(40))
    UI.text(0, 40, "Prepare to fight!", "TOP", {1,1,1,1}, love.graphics.newFont(40))
end

function BattleUI:updateResult(dt)
    local state = self.state
    if not (state.state == 'result' or state.state == 'rewards') then return end

    if state.state == 'rewards' then
        if self.rewards_tween then
            if self.rewards_tween:update(dt) then
                self.show_rewards_items = true
                self.rewards_print_progress = self.rewards_print_progress + dt * 2
            end
        end
    end
end

-- =============================================================
-- Окно характеристик юнита
-- =============================================================

function BattleUI:drawUnitInfo(unit)
    if not unit then return end

    -- Динамическая высота под содержимое
    local n_spells = #(unit.spells or {})
    local n_mods   = #(unit.modifiers or {})
    local base_h   = 50 + infoTitleFont:getHeight() + infoFontHeight * 3 + 7 * (infoFontHeight + 4) + n_spells * (infoSmallFontHeight + 2)
    local mods_h   = n_mods > 0 and (8 + infoFontHeight + n_mods * (infoSmallFontHeight + 2)) or 0
    local panel_h  = base_h + mods_h + 14

    local panel_w = 300
    local panel_x = -20
    local panel_y = 100
    local pad     = 12

    -- Фон
    UI.setStyle({
        draw_border      = true,
        border_color     = { 0.85, 0.85, 0.6, 1 },
        border_width     = 2,
        background_color = { 0.10, 0.10, 0.15, 0.96 },
        corner_radius    = 10,
    })
    UI.nextPosition("TOPRIGHT", "root")
    UI.backdrop("battle_info_bg", panel_x, panel_y, panel_w, panel_h, "TOPRIGHT")

    UI.setStyle({})

    -- Имя
    UI.nextPosition("TOPLEFT")
    UI.text(pad, pad, unit.name or "?", "TOPLEFT", { 1, 1, 1, 1 }, infoTitleFont)

    -- Атрибут
    local attr_name  = (ATTRIBUTES and ATTRIBUTES[unit.attribute]) or unit.attribute or "?"
    local attr_color = (ATTRIBUTES_COLORS and ATTRIBUTES_COLORS[unit.attribute]) or { 1, 1, 1, 1 }
    UI.nextPosition("BOTTOMLEFT")
    UI.text(0, pad,
        { { 1, 1, 1, 1 }, "Attribute: ", attr_color, attr_name },
        "TOPLEFT", nil, infoFont)

    -- Элемент
    local elem_name  = (ELEMENTS and ELEMENTS[unit.element]) or unit.element or "?"
    local elem_color = (ELEMENTS_COLORS and ELEMENTS_COLORS[unit.element]) or { 1, 1, 1, 1 }
    UI.nextPosition("BOTTOMLEFT")
    UI.text(0, 4,
        { { 1, 1, 1, 1 }, "Element: ", elem_color, elem_name },
        "TOPLEFT", nil, infoFont)

    -- Боевые статы
    local stats = {
        { "Health",       (unit.health or 0) .. "/" .. (unit.max_health or 0) },
        { "Energy",       (unit.energy or 0) .. "/" .. (unit.max_energy or 0) },
        { "Damage",       tostring(unit.damage or 0) },
        { "Armor",        tostring(unit.armor or 0) },
        { "Initiative",   tostring(unit.initiative or 0) },
        { "Attack range", tostring(unit.attack_range or 0) },
        { "Move range",   tostring(unit.move_range or 0) },
    }

    UI.nextPosition("BOTTOMLEFT", _, 0, 10)
    for _, entry in ipairs(stats) do
        UI.text(0, 4, entry[1] .. ": " .. entry[2], "TOPLEFT", { 1, 1, 1, 1 }, infoFont)
        UI.nextPosition("BOTTOMLEFT")
    end

    -- Способности
    UI.text(0, 10, "Spells:", "TOPLEFT", { 0.85, 0.85, 0.85, 1 }, infoFont)
    UI.nextPosition("BOTTOMLEFT", _, 8, 2)

    for _, spell in ipairs(unit.spells or {}) do
        local cd     = spell.current_cooldown or 0
        local suffix = cd > 0 and (" (CD: " .. cd .. ")") or ""
        UI.text(0, 2, "\226\128\162 " .. (spell.name or "?") .. suffix,
            "TOPLEFT", { 1, 1, 1, 1 }, infoSmallFont)
        UI.nextPosition("BOTTOMLEFT")
    end

    -- Активные эффекты / модификаторы
    if n_mods > 0 then
        UI.nextPosition("BOTTOMLEFT", _, -8, 0)
        UI.text(0, 6, "Effects:", "TOPLEFT", { 0.85, 0.85, 0.85, 1 }, infoFont)
        UI.nextPosition("BOTTOMLEFT", _, 8, 2)

        for _, m in ipairs(unit.modifiers) do
            local dur = m.duration and (" [" .. m.duration.value .. "]") or ""
            local label = m.name or m.id or "?"
            UI.text(0, 2, "\226\128\162 " .. label .. dur,
                "TOPLEFT", { 0.85, 0.85, 0.85, 1 }, infoSmallFont)
            UI.nextPosition("BOTTOMLEFT")
        end
    end
end

local shard_order = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
local shard_labels = {
    wild = 'Wild shards', mystic = 'Mystic shards',
    mechanic = 'Mechanic shards', ancient = 'Ancient shards',
    chaos = 'Chaos shards',
}

function BattleUI:draw(state)
    -- Лог
    local logH = self.logOffset * 3 + (self.logFont:getHeight() + 2) * 2
    UI.setStyle({
        draw_border = true,
        border_color = self.logBorderColor,
        background_color = self.logBackgroundColor,
    })
    UI.nextPosition("BOTTOM", "root")
    UI.backdrop("battlelog_backdrop", 0, -self.logOffset, self.logW, logH, "BOTTOM")
    UI.setStyle()
    if #state.log > 0 then
        UI.nextPosition("TOP")
        UI.text(0, self.logOffset, state.log[1], "TOP", self.logTextColor, self.logFont)
        if state.log[2] then
            UI.nextPosition("BOTTOM")
            UI.text(0, self.logOffset, state.log[2], "TOP", self.logTextColor, self.logFont)
        end
    end

    if state.state == 'rewards' or state.state == 'result' then
        local w, h = self.rewards_w, self.rewards_h
        UI.setStyle({
            draw_border = true,
            border_width = 1,
            border_color = Brighter({ 0.3, 0.34, 0.5, 1 }, 1.5),
            background_color = { 0.3, 0.34, 0.5, 1 },
            corner_radius = 2,
        })
        UI.nextPosition("CENTER", "root")
        UI.backdrop("rewards_backdrop", 0, -180, w, h, "TOP")
        UI.nextPosition("TOP")
        UI.text(0, 5, self.result_text, "TOP", {1,1,1,1}, result_font)
        
        if self.show_rewards_items then
            local str = tostring(state.exp_reward) .. ' experience'
            UI.nextPosition("TOPLEFT", "rewards_backdrop", 10, result_font:getHeight() + 5)
            UI.text(0, 8, Badprint(str, self.rewards_print_progress), "TOPLEFT", {1,1,1,1}, love.graphics.newFont(18))
            for _, reward in ipairs(state.rewards) do
                str = tostring(reward.value) .. ' ' .. reward.currency
                UI.nextPosition("BOTTOMLEFT")
                UI.text(0, 4, Badprint(str, self.rewards_print_progress), "TOPLEFT", {1,1,1,1}, love.graphics.newFont(18))
            end

            -- Осколки
            for _, attr in ipairs(shard_order) do
                local amount = state.shards_gained[attr]
                if amount and amount > 0 then
                    str = '+' .. amount .. ' ' .. (shard_labels[attr] or attr)
                    UI.nextPosition("BOTTOMLEFT")
                    UI.text(0, 4, Badprint(str, self.rewards_print_progress), "TOPLEFT", {1,1,1,1}, love.graphics.newFont(18))
                end
            end

            -- Эссенция
            local essence_bonus = select(1, RunState:getStat('essence_bonus'))
            if essence_bonus > 0 then
                str = '+' .. essence_bonus .. ' essence'
                UI.nextPosition("BOTTOMLEFT")
                UI.text(0, 4, Badprint(str, self.rewards_print_progress), "TOPLEFT", {1,1,1,1}, love.graphics.newFont(18))
            end
        end

        UI.setStyle()
        UI.nextPosition("BOTTOM", "rewards_backdrop")
        if UI.button("result_btn", 0, 10, 110, 40, "Continue", "TOP") then
            if state.state == 'result' then
                if state.result == 'lose' then
                    state:returnToLevelmap({r=0,g=0,b=0})
                else
                    state.state = 'rewards'
                    self.result_text = "Rewards:"
                    self.rewards_h = result_height
                    self.rewards_tween = Tween.new(0.75, self, { rewards_h = 220 }, 'inOutCubic')
                    self.show_rewards_items = false
                    self.rewards_print_progress = 0
                end
            elseif state.state == 'rewards' then
                state:returnToLevelmap({ r = 1, g = 1, b = 1 })
            end
        end
    end

    if state.info_unit then
        self:drawUnitInfo(state.info_unit)
    end
end

return BattleUI