local itemList = require 'src.items'

local fontSize = 14
local font = love.graphics.newFont(fontSize)

local itemFontSize = 12
local itemFont = love.graphics.newFont(itemFontSize)

local itemRadius = 20
-- local offset = itemRadius * 0.6
local offset = 5
local textOffsetX = 5

local buttonWidth = 140
local buttonHeight = 24

local itemWidth = 120
local itemHeight = 20

local Inventory = Class{}

function Inventory:init(x, y, inventory)
    self.x = x
    self.y = y
    self.w = buttonWidth
    self.h = buttonHeight

    -- self.items = inventory

    self.enabled = true
    self.opened = false
    self.cursorInside = false
    self.items = {}
end

function Inventory:enable()
    self.enabled = true
end

function Inventory:disable()
    self.enabled = false
end

function Inventory:setup(inventory)
    for pos, item in ipairs(inventory) do
        if item.item.usableOnMap then
            item.isActive = true
        else
            item.isActive = false
        end
    end

    self.items = inventory
end

function Inventory:update(dt)
    self.cursorInside = false
    local mx, my = love.mouse.getPosition()
    if mx >= self.x and mx <= self.x + buttonWidth
    and my >= self.y and my <= self.y + buttonHeight
    then
        self.cursorInside = true
    end

    if self.opened then
        local x = self.x
        local y = self.y + buttonHeight + offset
        for pos, item in ipairs(self.items) do
            item.cursorInside = false
            if mx >= x and mx <= x + itemWidth
            and my >= y and my <= y + itemHeight
            then
                item.cursorInside = true
            end

            y = y + itemHeight + offset
        end
    end
end

function Inventory:draw()
    love.graphics.setLineWidth(1)
    local color = self.opened and { 0.75, 0.75, 0.75 } or { 0.5, 0.5, 0.5 }
    if self.cursorInside then color = Urutora.utils.brighter(color) end
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', self.x, self.y, buttonWidth, buttonHeight)
    love.graphics.setColor(0.0, 0.0, 0.0, 1)
    love.graphics.rectangle('line', self.x, self.y, buttonWidth, buttonHeight)

    local fontHeight = font:getHeight('Items')
    local ty = self.y + buttonHeight/2 - fontHeight/2
    
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(font)
    PrintText('Items', self.x + textOffsetX, ty)

    if self.opened then
        love.graphics.setFont(itemFont)
        local x = self.x
        local y = self.y + buttonHeight + offset
        for pos, item in ipairs(self.items) do
            color = { 0.75, 0.75, 0.75 }
            if item.cursorInside then color = Urutora.utils.brighter(color) end
            if not self.enabled or not item.isActive then color = { 0.5, 0.5, 0.5 } end
            love.graphics.setColor(color)
            love.graphics.rectangle('fill', x, y, itemWidth, itemHeight)
            love.graphics.setColor(0.0, 0.0, 0.0, 1)
            love.graphics.rectangle('line', x, y, itemWidth, itemHeight)

            local text = item.item.name .. ', ' .. tostring(item.quantity)
            fontHeight = itemFont:getHeight(text)
            ty = y + itemHeight/2 - fontHeight/2

            love.graphics.setColor(0, 0, 0, 1)
            PrintText(text, x + textOffsetX, ty)
            
            y = y + itemHeight + offset
        end
        
        x = self.x
        y = self.y + buttonHeight + offset
        for pos, item in ipairs(self.items) do
            if item.cursorInside then
                local name = item.item.name
                local description = item.item.description
                
                -- local nameW = font:getWidth(name)
                -- local nameH = font:getHeight(name)
    
                local descW = itemFont:getWidth(description) + textOffsetX + textOffsetX
                local descH = itemFont:getHeight(description) + 6
    
                -- local rectW = math.max(nameW, descW) + 4
                -- local rectH = nameH + descH + 6
                love.graphics.setColor(0.8, 0.8, 0.8, 1)
                love.graphics.rectangle('fill', x + itemWidth + offset, y, descW, descH)
                
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle('line', x + itemWidth + offset, y, descW, descH)
                ty = y + itemHeight/2 - fontHeight/2
    
                love.graphics.setColor(0, 0, 0, 1)
                -- PrintText(name, x + 2, y + oy + 2)
                PrintText(description, x + itemWidth + offset + textOffsetX, ty)
            end
            y = y + itemHeight + offset
        end
    end
end

function Inventory:mousepressed(x, y)
    if self.cursorInside then
        self.opened = not self.opened
    end
    if not self.enabled then return end

    for pos, item in ipairs(self.items) do
        if item.cursorInside and item.isActive then
            Levelmap:set_target_mode(item.item)
        end
    end
end

return Inventory