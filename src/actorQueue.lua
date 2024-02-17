local tween = require 'lib.tween'

local styleFinished = {
    fgColor = { 0.5, 0.5, 0.5, 0.5 },
    bgColor = { 0, 0, 0, 0 }
}
local styleCurrent = {
    bgColor = { love.math.colorFromBytes(39, 170, 225) }
}
local styleAwaiting = {
    bgColor = { 0, 0, 0, 0 }
}
local styleNext = {
    fgColor = { love.math.colorFromBytes(0, 0, 0, 0) },
    bgColor = { 0, 0, 0, 0 }
}
local styleText = {
    -- outline = 'line'
    bgColor = { love.math.colorFromBytes(231, 74, 153, 125) }
}

local rows = 7
local cellHeight = nil

local function addText(parent, row, col)
    parent:addAt(row, col, Urutora.label({
        text = 'Next:'
    }):setStyle(styleText))
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

    local w = (love.graphics.getWidth() - x) - 10
    local h = (love.graphics.getHeight() - y) - 10
    local mainPanel = Urutora.panel({
        x = x, y = y,
        w = w, h = h,
        cols = 10, rows = rows,
        csx = 60
    })

    urutora:add(mainPanel)

    -- self.tweens = {}
    self.panels = {}
    self.mainPanel = mainPanel
    self.currentPanel = nil
    self.nextPanel = nil
    self.opacityTween = nil
    
    self:create_next_panel()
end

function Queue:create_next_panel()
    local col = #self.panels + 1
    local panel = Urutora.panel({
        cols = 1, rows = rows-1,
        cellHeight = cellHeight
    })
    addText(self.mainPanel, 1, col)
    self.mainPanel:rowspanAt(2, col, rows-1):addAt(2, col, panel)

    table.insert(self.panels, panel)
    self.nextPanel = panel

    styleNext.fgColor[4] = 0
    self.opacityTween = tween.new(1, styleNext.fgColor, { [4] = 1 })

    return panel
end

function Queue:fill_next_panel()
    local nextPanel = self.nextPanel

    for i, unit in ipairs(self.all_units) do
        local t = nextPanel:getChildren(i, 1)
        if t then
            t.text = unit.name
        else
            local text = Urutora.label({
                text = unit.name,
                align = 'left',
            }):setStyle(styleNext)
            self.nextPanel:addAt(i, 1, text)
        end
    end
end

function Queue:add_actor(actor)
    table.insert(self.all_units, actor)
    table.insert(self.finished, actor)

    table.sort(self.all_units, function (a, b)
        return a.initiative > b.initiative
    end)

    self:fill_next_panel()
end

function Queue:new_round()
    self.round = self.round + 1

    for i = 1, #self.finished, 1 do
        local a = self.finished[i]
        table.insert(self.awaiting, a)
    end

    table.sort(self.awaiting, function (a, b)
        return a.initiative > b.initiative
    end)

    self.mainPanel:getChildren(1, self.round).text = 'Rnd' .. self.round .. ':'
    self.currentPanel = self.nextPanel
    self.currentPanel:setStyle(styleAwaiting)

    self:create_next_panel()
    self:fill_next_panel()

    self.finished = {}
    self.index = 0
end

function Queue:start_turn()
    if self.current then
        self.currentPanel:getChildren(self.index, 1):setStyle(styleFinished)
        self.current.acting = false
        table.insert(self.finished, self.current)
    end

    if not next(self.awaiting) then
        self:new_round()
    end
    
    self.index = self.index + 1
    local unit = table.remove(self.awaiting, 1)
    self.currentPanel:getChildren(self.index, 1):setStyle(styleCurrent)
    self.current = unit
    self.current:set_acting()
end

function Queue:end_turn()
    self.index = self.index + 1
end

function Queue:update(dt)
    local complete = self.opacityTween:update(dt)
end

return Queue