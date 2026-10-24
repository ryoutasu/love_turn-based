local Sprite = require 'src.sprite'

local fontSize = 9
local healthFont = love.graphics.newFont(fontSize)
local healthTextHeight = healthFont:getHeight()
local healthBarWidth = 64
local healthBarHeight = 16

local statWindowFont = love.graphics.newFont(16)

local spriteScale = 0.6

local CharacterList = Class{}

function CharacterList:init(x, y)
    self.x = x
    self.y = y

    self.list = {}
    self.panels = {}
    self.showBox = false

    self.highlighted = nil
    self.selected = nil
end

function CharacterList:setup(characters)
    self.list = {}

    local x, y = self.x, self.y
    for i, character in ipairs(characters) do

        local sprite = Sprite(character.sprite_path, character.color)
        local w, h = sprite.w * spriteScale, sprite.h * spriteScale
        local quad = love.graphics.newQuad(0, 0, w, h, w, h)
        
        table.insert(self.list, { sprite = sprite, quad = quad, character = character, cursorInside = false, x = x, y = y })

        y = y + h + healthBarHeight
    end
end

function CharacterList:update(dt)
    local mx, my = love.mouse.getPosition()

    local highlighted = nil
    for i, value in ipairs(self.list) do
        local _, _, w, h = value.quad:getViewport()
        local x, y = value.x, value.y

        if mx >= x and mx <= x + w
        and my >= y and my <= y + h then
            value.cursorInside = true
            highlighted = value
        else
            value.cursorInside = false
        end
    end
    
    self.highlighted = highlighted
end

function CharacterList:draw()
    for i, value in ipairs(self.list) do
        local x, y = value.x, value.y
        local _, _, w, h = value.quad:getViewport()

        local c = value.character
        love.graphics.setColor(1, 1, 1, 1)
        value.sprite:draw(value.quad, x, y, 0, 1, 1)

        if self.showBox then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(1, 1, 1, 1)
            if value.cursorInside then
                love.graphics.setColor(0, 1, 0, 1)
            end
            love.graphics.rectangle('line', x, y, w, h)
        end
        
        x = x + w / 2 - healthBarWidth / 2
        y = y + h - healthBarHeight / 2

        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.33, 1, 0.33, 1)
        love.graphics.rectangle('fill', x, y, healthBarWidth, healthBarHeight)
        
        love.graphics.setColor(0.25, .66, 0.25, 1)
        love.graphics.rectangle('line', x, y, healthBarWidth, healthBarHeight)
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        
        local tx = x + 3
        local ty = y + ((healthBarHeight - fontSize) / 2) - 1

        local healthString = c.health .. '/' .. c.max_health
        love.graphics.setFont(healthFont)
        PrintText(healthString, tx, ty)
    end

    -- Draw stats window for selected character
    if self.selected then
        local windowX = self.selected.x + 100
        local windowY = self.selected.y
        self:drawStatsWindow(self.selected.character, windowX, windowY)
    end
end

function CharacterList:mousepressed(button)
    if button == 1 then  -- left click
        if self.highlighted then
            if self.selected == self.highlighted then
                self.selected = nil
            else
                self.selected = self.highlighted
            end
        else
            self.selected = nil
        end
    end
end

function CharacterList:drawTextWithOutline(text, x, y, outlineColor)
    local r,g,b,a = love.graphics.getColor()
    -- Draw outline
    love.graphics.setColor(outlineColor or {0, 0, 0, 1})
    love.graphics.print(text, x-1, y-1)
    love.graphics.print(text, x+1, y-1)
    love.graphics.print(text, x-1, y+1)
    love.graphics.print(text, x+1, y+1)
    -- Draw text
    love.graphics.setColor(r,g,b,a)
    love.graphics.print(text, x, y)
end

function CharacterList:drawStatsWindow(character, x, y)
    local windowWidth = 200
    local windowHeight = 200
    local padding = 10

    -- Draw window background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle('fill', x, y, windowWidth, windowHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('line', x, y, windowWidth, windowHeight)

    -- Draw character stats
    love.graphics.setFont(statWindowFont)
    local textY = y + padding
    local textX = x + padding
    
    self:drawTextWithOutline("Name: " .. character.name, textX, textY)
    textY = textY + 20
    self:drawTextWithOutline("Health: " .. character.health .. "/" .. character.max_health, textX, textY)
    textY = textY + 20
    self:drawTextWithOutline("Energy: " .. character.energy .. "/" .. character.max_energy, textX, textY)
    textY = textY + 20
    self:drawTextWithOutline("Damage: " .. character.damage, textX, textY)
    textY = textY + 20
    self:drawTextWithOutline("Armor: " .. (character.armor or 0), textX, textY)
    textY = textY + 20
    self:drawTextWithOutline("Moves: ", textX, textY)
    for index, spell in ipairs(character.spells) do
        textY = textY + 20
        self:drawTextWithOutline("> " .. spell.name .. " <", textX, textY)
    end
end

return CharacterList