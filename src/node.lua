local sprite = require 'src.sprite'

local offset = 75

local nodeRadius = 25
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

local images = {
    ['start'] = (path .. trainerPath),
    ['wild'] = (path .. wildPath),
    ['trainer'] = (path .. trainerPath),
    ['event'] = (path .. eventPath),
    ['rest'] = (path .. restPath),
    ['shop'] = (path .. eventPath),
    ['end'] = (path .. bossPath)
}

local sprites = {
    ['start'] = sprite(path .. trainerPath),
    ['wild'] = sprite(path .. wildPath),
    ['trainer'] = sprite(path .. trainerPath),
    ['event'] = sprite(path .. eventPath),
    ['rest'] = sprite(path .. restPath),
    ['shop'] = sprite(path .. eventPath),
    ['end'] = sprite(path .. bossPath)
}

local fontSize = 14
local labelFont = love.graphics.newFont(fontSize)
local labels = {
    ['start'] = 'Start',
    ['wild'] = 'Bushes',
    ['trainer'] = 'Trainer',
    ['event'] = 'Random event',
    ['rest'] = 'Rest',
    ['shop'] = 'Shop',
    ['end'] = 'Boss fight'
}

local node_gamestates = {
    ['start'] = BattleState,
    ['wild'] = BattleState,
    ['trainer'] = BattleState,
    ['event'] = EventState,
    ['rest'] = RestState,
    ['shop'] = ShopState,
    ['end'] = BattleState
}

-- node types:
-- start - wild, but easier
-- wild
-- trainer
-- event
-- rest
-- shop
-- end - boss battle

local defualtType = 'wild'

local Node = Class{}

function Node:init(id, x, y, isOpen, type)
    self.id = id
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

    if type == 'wild' or type == 'trainer' then
        self.enemies_count = math.random(2, 3)
    end
end

function Node:getGamestate()
    return node_gamestates[self.type]
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
    if self.isCompleted then
        UI.setStyle({
            border_color = nodeCompletedLineColor,
            border_width = 4,
            background_color = nodeClosedFillColor,
        })
    elseif self.isOpen then
        UI.setStyle({
            border_color = nodeElseLineColor,
            border_width = 6,
            background_color = nodeClosedFillColor,
        })
    else
        UI.setStyle({
            border_color = nodeLineColor,
            border_width = 2,
            background_color = nodeClosedFillColor,
        })
    end

    local released, hovered = UI.node("node_"..self.id, self.x, self.y, nodeRadius, images[self.type], self.isDiscovered or DEBUG)
    if released then
        if self.isOpen then
            if not self.isCompleted then
                Levelmap.currentNode = self
                
                Gamestate.push(FadeInState, { color = { r = 1, g = 1, b = 1 }, time = 1, onFadeComplete = function()
                    Levelmap.active = false
                    Gamestate.push(self:getGamestate(), { player = Levelmap.player, node = self })
                    Gamestate.push(FadeOutState, { color = { r = 1, g = 1, b = 1 }, time = 1 })
                end })
            end

            PlaySound(ButtonClickSound)
        else
            PlaySound(ErrorSound, 0.4)
        end
    end

    if hovered then
        local text = labels[self.type] or "Undiscovered"
        local w, h = labelFont:getWidth(text), labelFont:getHeight()
        UI.setStyle({ })
        UI.nextPosition("TOP")
        UI.backdrop("node_backdrop_"..self.id, 0, -20, w + 16, h + 12, "BOTTOM")
        UI.nextPosition("CENTER")
        UI.text(0, 0, labels[self.type] or "Undiscovered", "CENTER", { 1, 1, 1, 1 }, labelFont)
    end
end

return Node