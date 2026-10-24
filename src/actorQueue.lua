local tween = require 'lib.tween'

local playerPanelColor = { love.math.colorFromBytes(39, 170, 225) }
local enemyPanelColor = { love.math.colorFromBytes(225, 58, 39) }

local rows = 10

local panelWidth = 100
local panelHeight = 30
local panelOffset = 10

local panelX = 1150
local panelY = 100
local panelAddX = panelX + 100

local currentSize = 1.2
local currentY = panelY - 50
local currentX = panelX - (panelWidth * currentSize - panelWidth)

local defualtFont = love.graphics.newFont(12)
local currentFont = love.graphics.newFont(14)

local tween_time = 0.5
local easing = 'outCubic'

local function sort(a, b)
    local a_initiative = a:get_stat('initiative')
    local b_initiative = b:get_stat('initiative')
    if a_initiative == b_initiative then return a.queue_index < b.queue_index end
    return a_initiative > b_initiative
end

local Panel = Class{}

function Panel:init(x, y, actor)
    self.x = x
    self.y = y
    self.actor = actor
    actor.panel = self

    self.a = 0
    self.color = actor.is_player and playerPanelColor or enemyPanelColor
    self.size = 1

    self.isCurrent = false
    self.toDelete = false
    self.order = 0
    self.cursorInside = false
    self.highlighted = false
    self.is_next = true
end

function Panel:update(dt)
    local mx, my = love.mouse.getPosition()
    local cursorInside = false

    if mx >= self.x and mx <= self.x + panelWidth * self.size
    and my >= self.y and my <= self.y + panelHeight * self.size then
        cursorInside = true
    end

    if cursorInside and not self.cursorInside then
        self.cursorInside = true
        self.actor.show_name = true
    end

    if not cursorInside and self.cursorInside then
        self.cursorInside = false
        self.actor.show_name = false
    end

    if self.tween then
        local complete = self.tween:update(dt)

        if complete then
            self.tween = nil

            if self.toDelete then
                return true
            end
        end
    end

    return false
end

function Panel:draw()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.a)
    love.graphics.rectangle('fill', self.x, self.y, panelWidth * self.size, panelHeight * self.size)

    if self.cursorInside or self.actor.show_name then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(.0, .0, .0, self.a)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(.3, .3, .3, self.a)
    end
    love.graphics.rectangle('line', self.x, self.y, panelWidth * self.size, panelHeight * self.size)

    love.graphics.setFont(self.isCurrent and currentFont or defualtFont)
    love.graphics.setColor(1, 1, 1, self.a)
    if self.actor.name == 'Next:' then
        love.graphics.setColor(0, 0, 0, 1)
    end
    local offset = math.floor(8 * self.size)
    PrintText(self.actor.name, self.x + offset, self.y + offset)
end

local Queue = Class{}

function Queue:init()
    self.turn_number = 0 -- starting from 1
    self.current = nil
    self.awaiting = {}
    self.all_units = {}
    self.next_turn = {}
    self.round = 0

    self.tweens = {}
    self.panels = {}
    self.next_turn_panel = self:create_panel({ name = 'Next:' }, 1)
    self.next_turn_panel.color = { 1, 1, 1, 1 }
    self.next_turn_panel.order = 100

    self.index = 1
end

local function getRowY(row)
    return (panelHeight * (row - 1)) + (panelOffset * (row - 1))
end

function Queue:get_actor_panel(actor, is_next)
    is_next = is_next or false
    for index, panel in ipairs(self.panels) do
        if panel.actor == actor and panel.is_next == is_next then
            return panel
        end
    end
end

function Queue:create_panel(actor, row)
    local x, y = panelAddX, panelY + getRowY(row)

    local panel = Panel(x, y, actor)
    table.insert(self.panels, panel)

    panel.tween = tween.new(tween_time, panel, { x = panelX, y = y, a = 1, size = 1 }, easing)
    return panel
end

function Queue:actor_exists(actor)
    for index, value in ipairs(self.all_units) do
        if value == actor then
            return true
        end
    end
    return false
end

function Queue:add_actor(actor)
    table.insert(self.all_units, actor)
    actor.queue_index = self.index
    self.index = self.index + 1

    local row = 0
    for index, next_actor in ipairs(self.next_turn) do
        if next_actor:get_stat('initiative') < actor:get_stat('initiative') then
            table.insert(self.next_turn, index, actor)
            row = index
            break
        end
    end

    if row == 0 then
        table.insert(self.next_turn, actor)
        row = #self.next_turn
    end

    self:create_panel(actor, row + #self.awaiting + 1)

    if row < #self.next_turn then
        for i = row + 1, #self.next_turn do
            local actorToMove = self.next_turn[i]
            local panel = self:get_actor_panel(actorToMove, true)
            
            panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(i + #self.awaiting + 1), a = 1, size = 1 }, easing)
        end
    end
    
    self:sort_next()
end

function Queue:remove_panel(panel)
    panel.tween = tween.new(tween_time, panel, { x = panelAddX, a = 0, size = 1 }, 'inCirc')
    panel.toDelete = true
    panel.order = 99
end

function Queue:remove_actor(actor)
    for i = #self.all_units, 1, -1 do
        if self.all_units[i] == actor then
            table.remove(self.all_units, i)
        end
    end

    for i = #self.awaiting, 1, -1 do
        if self.awaiting[i] == actor then
            table.remove(self.awaiting, i)
        end
    end

    for i = #self.next_turn, 1, -1 do
        if self.next_turn[i] == actor then
            table.remove(self.next_turn, i)
        end
    end

    table.sort(self.all_units, sort)

    table.sort(self.awaiting, sort)

    table.sort(self.next_turn, sort)

    -- self:remove_panel(self:get_actor_panel(actor, false))
    -- self:remove_panel(self:get_actor_panel(actor, true))
    for i, panel in ipairs(self.panels) do
        if panel.actor == actor then
            -- panel.tween = tween.new(tween_time, panel, { x = panelAddX, a = 0, size = 1 }, 'inCirc')
            -- panel.toDelete = true
            -- panel.order = 99
            self:remove_panel(panel)
        end
    end

    self:sort_next()
end

function Queue:sort_next()
    table.sort(self.next_turn, sort)

    local n = #self.awaiting + 2
    
    for i, actor in ipairs(self.next_turn) do
        local panel = self:get_actor_panel(actor, true)
        panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(n), a = 1, size = 1 }, easing)
        panel.order = n

        n = n + 1
    end

    table.sort(self.panels, function (a, b)
        return a.order > b.order
    end)
end

function Queue:new_round()
    self.round = self.round + 1

    for _, panel in ipairs(self.panels) do
        panel.is_next = false
    end

    table.sort(self.all_units, sort)

    for _, actor in ipairs(self.next_turn) do
        table.insert(self.awaiting, actor)
    end

    self.next_turn = {}

    local awaiting_count = #self.awaiting
    for i, actor in ipairs(self.all_units) do
        table.insert(self.next_turn, actor)
        self:create_panel(actor, i + awaiting_count)
    end

    self.turn_number = 0
end

function Queue:start_turn()
    if self.current then
        self.current.acting = false
        local panel = self:get_actor_panel(self.current)
        if panel then
            panel.isCurrent = false
            self:remove_panel(panel)
        end
    end

    if not next(self.awaiting) then
        self:new_round()
    end

    self.turn_number = self.turn_number + 1
    local unit = table.remove(self.awaiting, 1)
    self.current = unit
    self.current:set_acting()

    local panel = self:get_actor_panel(self.current)
    panel.tween = tween.new(tween_time, panel, { x = currentX, y = currentY, a = 1, size = 1.2 }, easing)
    panel.isCurrent = true
    panel.order = 0

    local n = 1
    for i, actor in ipairs(self.awaiting) do
        local panel = self:get_actor_panel(actor)
        panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(n), a = 1, size = 1 }, easing)
        panel.order = n

        n = n + 1
    end

    self.next_turn_panel.tween = tween.new(tween_time, self.next_turn_panel, { x = panelX, y = panelY + getRowY(n), a = 1, size = 1 }, easing)
    self.next_turn_panel.order = n
    -- n = n + 1
    
    -- for i, actor in ipairs(self.next_turn) do
    --     local panel = self:get_actor_panel(actor, true)
    --     panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(n), a = 1, size = 1 }, easing)
    --     panel.order = n

    --     n = n + 1
    -- end
    self:sort_next()
end

function Queue:restart_turn()
    self.turn_number = self.turn_number + 1
end

function Queue:end_turn()
    self.turn_number = self.turn_number + 1
end

function Queue:update(dt)
    for i = #self.panels, 1, -1 do
        local panel = self.panels[i]
        local delete = panel:update(dt)
        if delete then
            table.remove(self.panels, i)
        end
    end
end

function Queue:draw()
    for _, panel in pairs(self.panels) do
        panel:draw()
    end
end

return Queue