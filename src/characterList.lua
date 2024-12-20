local Sprite = require 'src.sprite'

local fontSize = 9
local healthFont = love.graphics.newFont(fontSize)

local CharacterList = Class{}

function CharacterList:init(x, y)
    self.x = x
    self.y = y

    self.list = {}
    self.panels = {}
    self.showBox = false

    self.highlighted = nil
end

function CharacterList:setup(characters)
    self.list = {}

    -- local x, y = self.x, self.y
    -- local oy = 0
    for i, character in ipairs(characters) do
        local ox = (64 + 16 + 8) * (i-1)

        local sprite = Sprite(character.sprite_path)
        local rect = character.rect
        local quad = love.graphics.newQuad(0, 0, rect[1], rect[2], rect[3], rect[4])

        local _, _, w, h = quad:getViewport()
        local x, y = self.x - w/2 + 32, self.y - h/2 + 32 + ox
        
        table.insert(self.list, { sprite = sprite, quad = quad, character = character, cursorInside = false, x = x, y = y })

        -- oy = oy + 64 + 16 + 8
    end
end

function CharacterList:update(dt)
    local mx, my = love.mouse.getPosition()

    local highlighted = nil
    for i, value in ipairs(self.list) do
        -- local ox = (64 + 16 + 8) * (i-1)
        local _, _, w, h = value.quad:getViewport()
        -- local x, y = self.x - w/2 + 32, self.y - h/2 + 32 + ox
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
    -- local x, y = self.x, self.y

    local healthW, healthH = 64, 16
    for i, value in ipairs(self.list) do
        local ox = (64 + 16 + 8) * (i-1)
        local x, y = value.x, value.y
        local _, _, w, h = value.quad:getViewport()
        -- local x, y = self.x - w/2 + 32, self.y - h/2 + 32 + ox

        local c = value.character
        love.graphics.setColor(1, 1, 1, 1)
        value.sprite:draw(value.quad, x, y, 0, c.sprite_sx or 1, c.sprite_sy or 1)

        if self.showBox then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(1, 1, 1, 1)
            if value.cursorInside then
                love.graphics.setColor(0, 1, 0, 1)
            end
            love.graphics.rectangle('line', x, y, w, h)
        end
        
        -- x, y = self.x, self.y + ox + 64
        x = x + w / 2 - healthW / 2
        y = y + h - healthH / 2

        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.33, 1, 0.33, 1)
        love.graphics.rectangle('fill', x, y, healthW, healthH)
        
        love.graphics.setColor(0.25, .66, 0.25, 1)
        love.graphics.rectangle('line', x, y, healthW, healthH)
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        
        local tx = x + 3
        local ty = y + ((healthH - fontSize) / 2) - 1

        local healthString = c.health .. '/' .. c.max_health
        love.graphics.setFont(healthFont)
        PrintText(healthString, tx, ty)
    end
end

function CharacterList:mousepressed(button)
end

return CharacterList