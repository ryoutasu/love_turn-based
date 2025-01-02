local sprite = require 'src.sprite'

local offset = 75

local nodeRadius = 35
local nodeLineColor = { love.math.colorFromBytes(120, 120, 130) }
local nodeCompletedLineColor = { love.math.colorFromBytes(32, 192, 48) }
local nodeFightLineColor = { love.math.colorFromBytes(200, 64, 64) }
-- local nodeCompletedLineColor = { love.math.colorFromBytes(200, 64, 64) }
local nodeElseLineColor = { love.math.colorFromBytes(255, 255, 255) }

local nodeOpenFillColor = { love.math.colorFromBytes(39, 170, 225) }
local nodeClosedFillColor = { love.math.colorFromBytes(150, 150, 150) }
local nodeCompletedFillColor = { love.math.colorFromBytes(10, 128, 20) }
local nodeEndFillColor = { love.math.colorFromBytes(128, 16, 16) }
local nodeSelectLineColor = { love.math.colorFromBytes(10, 70, 100) }

local completeRingColor = { love.math.colorFromBytes(64, 192, 96, 228) }
local completeRingRadius = nodeRadius * 0.6

local path = 'resources/'
local fightPath = 'fight.png'
local wildPath = 'wild_icon_indexed.png'
local trainerPath = 'trainer_icon_indexed_clean.png'
local eventPath = 'event.png'
local restPath = 'rest.png'
local bossPath = 'boss.png'

local sprites = {
    ['start'] = sprite(path .. trainerPath),
    -- ['fight'] = sprite(path .. fightPath),
    ['wild'] = sprite(path .. wildPath),
    ['trainer'] = sprite(path .. trainerPath),
    ['event'] = sprite(path .. eventPath),
    ['rest'] = sprite(path .. restPath),
    ['end'] = sprite(path .. bossPath)
}

local fontSize = 14
local labelFont = love.graphics.newFont(fontSize)
local labels = {
    ['start'] = 'Start',
    -- ['fight'] = 'Fight',
    ['wild'] = 'Bushes',
    ['trainer'] = 'Trainer',
    ['event'] = 'Random event',
    ['rest'] = 'Rest',
    ['end'] = 'Boss fight'
}

local typeGamestates = {
    ['start'] = BattleState,
    -- ['fight'] = BattleState,
    ['wild'] = BattleState,
    ['trainer'] = BattleState,
    ['event'] = EventState,
    ['rest'] = RestState,
    ['end'] = BattleState
}

-- node types:
-- start - fight
-- fight - wild pokemon or trainer
-- event
-- rest
-- end - boss battle

local defualtType = 'wild'

local Node = Class{}

function Node:init(x, y, isOpen, type)
    self.x = x
    self.y = y
    self.radius = nodeRadius

    self.isOpen = isOpen or false
    self.isDiscovered = isOpen or false
    self.isCompleted = false
    self.isFinish = false
    self.cursorInside = false

    self.type = type or defualtType

    self.sprite = sprites[type or defualtType]
    self.spriteX = x - nodeRadius / 2
    self.spriteY = y - nodeRadius / 2
    self.spriteScaleX = nodeRadius / self.sprite.w
    self.spriteScaleY = nodeRadius / self.sprite.h
end

function Node:getGamestate()
    return typeGamestates[self.type]
end

function Node:update(dt)
    local mx, my = love.mouse.getPosition()
    local cursorInside = false

    local dx, dy = self.x - mx, self.y - my
    if dx * dx + dy * dy <= self.radius * self.radius then
        cursorInside = true
    end

    if cursorInside and not self.cursorInside then
        self.radius = nodeRadius * 1.2
        self.cursorInside = true
    end

    if not cursorInside and self.cursorInside then
        self.radius = nodeRadius
        self.cursorInside = false
    end
end

function Node:draw_label()
    if not self.cursorInside then return end
    
    local text = (self.isDiscovered or DEBUG) and labels[self.type] or 'Undiscovered'

    local x, y = self.x, self.y

    local w = labelFont:getWidth(text) + 4
    local h = fontSize + 4
    local rx = math.ceil(x - w / 2)
    local ry = math.ceil(y - nodeRadius - fontSize * 2)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', rx, ry, w, h)
    

    love.graphics.setFont(labelFont)
    love.graphics.setColor(0, 0, 0, 1)

    love.graphics.print(text, rx + 2, ry + 1)
end

function Node:draw()
    local scale = self.cursorInside and 1.2 or 1
    local radius = nodeRadius * scale

    love.graphics.setColor(nodeClosedFillColor)
    love.graphics.circle('fill', self.x, self.y, radius)

    if self.isDiscovered or DEBUG then
        love.graphics.setColor(1, 1, 1, 1)
        local x = self.x - radius
        local y = self.y - radius
        self.sprite:draw(_, x, y, 0, radius / self.sprite.w * 2, radius / self.sprite.h * 2)
    end

    if self.isCompleted then
        love.graphics.setLineWidth(14 * scale)
        love.graphics.setColor(completeRingColor)
        love.graphics.circle('line', self.x, self.y, completeRingRadius * scale)
    end

    if self.isCompleted then
        love.graphics.setLineWidth(4)
        love.graphics.setColor(nodeCompletedLineColor)
    elseif self.isOpen then
        love.graphics.setLineWidth(6)
        love.graphics.setColor(nodeElseLineColor)
    else
        love.graphics.setLineWidth(2)
        love.graphics.setColor(nodeLineColor)
    end
    
    -- love.graphics.setLineWidth(4)
    love.graphics.circle('line', self.x, self.y, radius)
    
    love.graphics.setLineWidth(1)
    self:draw_label()
end

return Node