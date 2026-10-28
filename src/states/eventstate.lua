-- src/eventstate.lua
local Events = require 'src.events'

local EventState = {}

-- ================================================================
-- Fonts / Layout / Colors
-- ================================================================

local titleFont  = love.graphics.newFont(26)
local textFont   = love.graphics.newFont(17)
local buttonFont = love.graphics.newFont(17)

local PANEL_MARGIN_H = 80
local PANEL_MARGIN_V = 60
local TEXT_PADDING   = 32

local BUTTON_W   = 340
local BUTTON_H   = 56
local BUTTON_GAP = 14

local COLOR_PANEL_BG     = { 0.08, 0.09, 0.14, 0.94 }
local COLOR_PANEL_BORDER = { 0.45, 0.55, 0.75, 1 }
local COLOR_TITLE        = { 1, 0.85, 0.4, 1 }
local COLOR_TEXT         = { 0.95, 0.95, 0.95, 1 }
local COLOR_BUTTON       = { 0.45, 0.52, 0.72, 1 }

-- ================================================================
-- Lifecycle
-- ================================================================

function EventState:init()
    self.steps         = nil
    self.currentStep   = 0
    self.player        = nil
    self.title         = nil
    self._closed       = false
    self._entered_step = false
end

function EventState:enter(from, args)
    self.player        = args.player
    self._closed       = false
    self._entered_step = false

    -- Сюжетная сцена имеет приоритет над случайным событием на узле:
    -- если узел размечен нитью, играем её, а не generic-событие.
    local node = args.node
    if node and node.story_scene then
        local result = EventState.generate_story(node, args.player, args.locked)
        if result then
            self.steps = result.steps
            self.title = result.title
            self.currentStep = 1
            self._story_node = node
            return
        end
    end

    -- Получаем определение события.
    -- Поддерживаем два формата возврата:
    --   1) возвращает таблицу шагов напрямую (старый формат)
    --   2) возвращает { steps = <шаги>, title = <заголовок> } (новый)
    local event_def = (node and node.event) or Events["abandonedCamp"]
    if not event_def then
        self.steps = nil
        return
    end

    local result = event_def(self.player)
    if type(result) == 'table' and result.steps then
        self.steps = result.steps
        self.title = result.title
    else
        self.steps = result
        self.title = nil
    end

    self.currentStep = 1
end

--- Генерирует payload сюжетной сцены для узла карты.
--- Возвращает nil, если сцену получить нельзя — тогда вызывающий
--- откатывается к обычному событию.
function EventState.generate_story(node, player, locked)
    local ok, SceneRunner = pcall(require, 'src.story.scene_runner')
    if not ok or not SceneRunner then return nil end

    local RunState = require 'src.states.run_state'
    local ThreadGenerator = require 'src.story.thread_generator'

    -- Контекст сцены: тот же, что использовал генератор нити.
    local okCtx, ctx = pcall(function()
        return ThreadGenerator.build_context(player, RunState)
    end)
    if not okCtx or not ctx then return nil end

    -- Узел знает свой scene id; ставим раннер на этот узел, чтобы
    -- scene_log и граф оставались согласованными.
    if RunState.story then
        RunState.story.node_id = node.story_id or RunState.story.node_id
    end

    -- Гейт закрыт — играем сцену alt_when_locked
    -- (например, «рассерженный мастер» вместо обычной сцены босса).
    -- Это SCENE id, а не id узла графа: граф остаётся на том же узле,
    -- меняется только сцена, которую он показывает.
    local scene_override
    if locked and node.alt_when_locked then
        scene_override = node.alt_when_locked
    end

    local okGen, result = pcall(SceneRunner.current, RunState, ctx, scene_override)
    if not okGen or not result then
        print('[story] scene generation failed: ' .. tostring(result))
        return nil
    end

    return result.payload
end

function EventState:leave()
    self.steps  = nil
    self.player = nil
    self.title  = nil
end

-- ================================================================
-- Update
-- ================================================================

function EventState:update(dt)
    if not self.steps then
        self:_close()
        return
    end

    local step = self.steps[self.currentStep]
    if not step then
        self:_close()
        return
    end

    -- Один раз на вход в шаг — колбэк on_enter
    if not self._entered_step then
        self._entered_step = true
        if step.on_enter then
            step.on_enter(self.player, step)
        end
    end

    self:_draw_step(step)
end

function EventState:_close()
    if self._closed then return end
    
    Gamestate.push(FadeInState, {
        color = { 1, 1, 1, 1 },
        time = 1,
        onFadeComplete = function()
            self._closed = true
            Levelmap.active = true
            Gamestate.pop({ complete = true })
            Gamestate.push(FadeOutState, { color = { 1, 1, 1, 1 }, time = 1 })
        end
    })
end

-- ================================================================
-- Отрисовка шага
-- ================================================================

function EventState:_draw_step(step)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    local panel_w = sw - PANEL_MARGIN_H * 2
    local panel_h = sh - PANEL_MARGIN_V * 2
    local panel_x = PANEL_MARGIN_H
    local panel_y = PANEL_MARGIN_V

    -- Панель
    UI.setStyle({
        draw_border      = true,
        border_color     = COLOR_PANEL_BORDER,
        border_width     = 2,
        background_color = COLOR_PANEL_BG,
        corner_radius    = 14,
    })
    UI.nextPosition("TOPLEFT", "root")
    UI.backdrop("event_panel", panel_x, panel_y, panel_w, panel_h, "TOPLEFT")

    -- Заголовок (если есть)
    local content_y = 32
    if self.title then
        UI.setStyle({})
        UI.setFont(titleFont)
        UI.nextPosition("TOP", "event_panel")
        UI.text(0, content_y, self.title, "TOP", COLOR_TITLE)
        content_y = content_y + titleFont:getHeight() + 20
    end

    -- Текст с переносом по словам
    local text_w = panel_w - TEXT_PADDING * 2
    local text   = step.text or ""
    if type(text) == 'function' then
        text = text(self.player, step)
    end

    local lines   = self:_wrapText(tostring(text), textFont, text_w)
    local line_h  = textFont:getHeight() + 4

    -- Кнопки (нужны для расчёта свободного места под текст)
    local buttons = step.buttons or {}
    if #buttons == 0 then
        buttons = { { text = "Continue", action = function() return 0 end } }
    end
    local n_buttons   = #buttons
    local total_btn_h = n_buttons * BUTTON_H + (n_buttons - 1) * BUTTON_GAP
    local btn_start_y = panel_h - total_btn_h - 32

    -- Обрезаем текст, если не влезает
    local max_text_h = btn_start_y - content_y - 24
    local max_lines  = math.max(1, math.floor(max_text_h / line_h))
    if #lines > max_lines then
        lines = { unpack(lines, 1, max_lines) }
        lines[max_lines] = lines[max_lines] .. "..."
    end

    UI.setStyle({})
    UI.setFont(textFont)
    UI.nextPosition("TOP", "event_panel")
    for i, line in ipairs(lines) do
        UI.text(0, content_y + (i - 1) * line_h, line, "TOP", COLOR_TEXT)
    end

    -- Кнопки
    UI.setStyle({
        draw_border      = true,
        border_color     = { 0, 0, 0, 1 },
        background_color = COLOR_BUTTON,
        corner_radius    = 8,
    })
    UI.setFont(buttonFont)
    UI.nextPosition("TOP", "event_panel")

    for i, button in ipairs(buttons) do
        local y = btn_start_y + (i - 1) * (BUTTON_H + BUTTON_GAP)
        if UI.button("event_btn_" .. i, 0, y, BUTTON_W, BUTTON_H,
            button.text or "...", "TOP") then
            self:_on_button(button)
        end
    end
end

-- ================================================================
-- Переход между шагами
-- ================================================================

function EventState:_on_button(button)
    PlaySound(ButtonClickSound)

    local next_step = 0
    if button.action then
        next_step = button.action(self.player) or 0
    end

    if next_step == 0 then
        self:_close()
    else
        self._entered_step = false
        self.currentStep   = next_step
    end
end

-- ================================================================
-- Утилиты
-- ================================================================

function EventState:_wrapText(text, font, max_width)
    local lines = {}
    if not text or text == "" then return lines end

    -- Поддерживаем явные \n (включая пустые строки для отступов)
    for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
        if paragraph == "" then
            table.insert(lines, "")
        else
            local current = ""
            for word in paragraph:gmatch("%S+") do
                local test = (current == "") and word or (current .. " " .. word)
                if font:getWidth(test) <= max_width then
                    current = test
                else
                    if current ~= "" then table.insert(lines, current) end
                    current = word
                end
            end
            if current ~= "" then table.insert(lines, current) end
        end
    end
    return lines
end

-- ================================================================
-- Draw / input hooks
-- ================================================================

function EventState:draw()
    -- Хук для кастомной графики (иллюстрации, иконки).
    -- Текст и кнопки рисуются в :update через UI.
end

function EventState:keypressed(key)
    if key == "escape" then
        self:_close()
    end
end

return EventState