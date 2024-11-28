local Sprite = require 'src.sprite'

local fontSize = 9
local healthFont = love.graphics.newFont(fontSize)

local CharacterList = Class{}

function CharacterList:init(x, y)
    self.x = x
    self.y = y

    self.list = {}
end

function CharacterList:setup(characters)
    self.list = {}

    -- local x, y = self.x, self.y
    -- local oy = 0
    for _, character in ipairs(characters) do
        local sprite = Sprite(character.sprite_path)
        local rect = character.rect
        local quad = love.graphics.newQuad(0, 0, rect[1], rect[2], rect[3], rect[4])
        -- local x, y = self.x - rect[1]/2 + 32, self.y - rect[2]/2 + 32 + oy
        table.insert(self.list, { sprite = sprite, quad = quad, character = character })

        -- oy = oy + 64 + 16 + 8
    end
end

function CharacterList:draw()
    -- local x, y = self.x, self.y

    for i, value in ipairs(self.list) do
        local ox = (64 + 16 + 8) * (i-1)
        -- local x, y = value.x, value.y
        local _, _, w, h = value.quad:getViewport()
        local x, y = self.x - w/2 + 32, self.y - h/2 + 32 + ox

        local c = value.character
        love.graphics.setColor(1, 1, 1, 1)
        value.sprite:draw(value.quad, x, y, 0, c.sprite_sx or 1, c.sprite_sy or 1)

        -- x = self.x
        -- y = y + 64
        x, y = self.x, self.y + ox + 64
        w, h = 64, 16

        love.graphics.setColor(0.33, 1, 0.33, 1)
        love.graphics.rectangle('fill', x, y, w, h)
        
        love.graphics.setColor(0.25, .66, 0.25, 1)
        love.graphics.rectangle('line', x, y, w, h)
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        
        local tx = x + 3
        local ty = y + ((h - fontSize) / 2) - 1

        local healthString = c.current_health .. '/' .. c.health
        love.graphics.setFont(healthFont)
        PrintText(healthString, tx, ty)
    end
end

return CharacterList