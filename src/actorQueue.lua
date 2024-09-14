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

local defualtFont = love.graphics.newFont(11)
local currentFont = love.graphics.newFont(14)

local tween_time = 0.5
local easing = 'outCirc'

local Panel = Class{}

function Panel:init(x, y, actor)
    self.x = x
    self.y = y
    self.actor = actor

    self.a = 0
    self.color = actor.is_player and playerPanelColor or enemyPanelColor
    self.size = 1

    self.isCurrent = false
    self.toDelete = false
end

function Panel:update(dt)
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

    love.graphics.setColor(.3, .3, .3, self.a)
    love.graphics.rectangle('line', self.x, self.y, panelWidth * self.size, panelHeight * self.size)

    love.graphics.setFont(self.isCurrent and currentFont or defualtFont)
    love.graphics.setColor(1, 1, 1, self.a)
    local offset = math.floor(8 * self.size)
    love.graphics.print(self.actor.name, self.x + offset, self.y + offset)
end

local Queue = Class{}

function Queue:init(urutora, x, y)
    self.u = urutora

    self.x = x
    self.y = y

    self.index = 0 -- starting from 1
    self.current = nil
    self.awaiting = {}
    self.finished = {}
    self.all_units = {}
    self.text = {}
    self.round = 0

    self.tweens = {}
    self.panels = {}
end

local function getRowY(row)
    return (panelHeight * (row - 1)) + (panelOffset * (row - 1))
end

function Queue:create_panel(actor, row)
    local x, y = panelAddX, panelY + getRowY(row)

    local panel = Panel(x, y, actor)
    self.panels[actor] = panel

    panel.tween = tween.new(tween_time, panel, { x = panelX, y = y, a = 1, size = 1 }, easing)
end

function Queue:add_actor(actor)
    table.insert(self.all_units, actor)

    local row = 0
    for index, finishedActor in ipairs(self.finished) do
        if finishedActor.initiative < actor.initiative then
            table.insert(self.finished, index, actor)
            row = index
            break
        end
    end

    if row == 0 then
        table.insert(self.finished, actor)
        row = #self.finished
    end

    self:create_panel(actor, row)

    if row < #self.finished then
        for i = row + 1, #self.finished do
            local actorToMove = self.finished[i]
            local panel = self.panels[actorToMove]
            
            panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(i), a = 1, size = 1 }, easing)
        end
    end
end

function Queue:remove_actor(actor)
    for i = #self.all_units, 1, -1 do
        if self.all_units[i] == actor then
            table.remove(self.all_units, i)
            print('removed from all_units')
        end
    end

    for i = #self.awaiting, 1, -1 do
        if self.awaiting[i] == actor then
            table.remove(self.awaiting, i)
            print('removed from awaiting')
        end
    end

    for i = #self.finished, 1, -1 do
        if self.finished[i] == actor then
            table.remove(self.finished, i)
            print('removed from finished')
        end
    end

    table.sort(self.all_units, function (a, b)
        return a.initiative > b.initiative
    end)

    table.sort(self.awaiting, function (a, b)
        return a.initiative > b.initiative
    end)

    table.sort(self.finished, function (a, b)
        return a.initiative > b.initiative
    end)

    local panel = self.panels[actor]
    panel.tween = tween.new(tween_time, panel, { x = panelAddX, y = panelY, a = 0, size = 1 }, 'inCirc')
    panel.toDelete = true
end

function Queue:new_round()
    self.round = self.round + 1

    table.sort(self.all_units, function (a, b)
        return a.initiative > b.initiative
    end)

    for _, actor in ipairs(self.finished) do
        table.insert(self.awaiting, actor)
    end

    self.finished = {}
    self.index = 0
end

function Queue:start_turn()
    if self.current then
        self.current.acting = false
        table.insert(self.finished, self.current)
        self.panels[self.current].isCurrent = false
    end

    if not next(self.awaiting) then
        self:new_round()
    end

    self.index = self.index + 1
    local unit = table.remove(self.awaiting, 1)
    self.current = unit
    self.current:set_acting()

    local panel = self.panels[self.current]
    panel.tween = tween.new(tween_time, panel, { x = currentX, y = currentY, a = 1, size = 1.2 }, easing)
    panel.isCurrent = true

    local n = 1
    for i = 1, #self.awaiting do
        local actor = self.awaiting[i]
        if actor then
            local panel = self.panels[actor]
            panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(n), a = 1, size = 1 }, easing)

            n = n + 1
        end
    end

    for i = 1, #self.finished do
        local actor = self.finished[i]
        if actor then
            local panel = self.panels[actor]
            panel.tween = tween.new(tween_time, panel, { x = panelX, y = panelY + getRowY(n), a = 1, size = 1 }, easing)

            n = n + 1
        end
    end
end

function Queue:end_turn()
    self.index = self.index + 1
end

function Queue:update(dt)
    for actor, panel in pairs(self.panels) do
        local delete = panel:update(dt)

        if delete then
            -- for i, panelToDelete in ipairs(self.panels) do
            --     if panelToDelete == panel then
            --         table.remove(self.panels, i)
            --     end
            -- end
            self.panels[actor] = nil
        end
    end
end

function Queue:draw()
    for _, panel in pairs(self.panels) do
        panel:draw()
    end
end

return Queue