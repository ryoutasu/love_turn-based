local itemList = require 'src.items'

local fontSize = 12
local quantityFont = love.graphics.newFont(fontSize)

local itemRadius = 20
local offset = itemRadius * 0.6

local Inventory = Class{}

function Inventory:init(x, y, inventory, node_type)
    self.x = x
    self.y = y
    
    for pos, item in ipairs(inventory) do
        item.isActive = true
        if item.item.name == 'Catcher' and node_type ~= 'wild' then
            item.isActive = false
        end
    end
    self.items = inventory

    self.enabled = false
end

function Inventory:enable()
    self.enabled = true
end

function Inventory:disable()
    self.enabled = false
end

function Inventory:update(dt)
    local mx, my = love.mouse.getPosition()
    
    local x, y = self.x, self.y
    for pos, item in ipairs(self.items) do
        love.graphics.setColor(item.item.color)
        love.graphics.circle('fill', x, y, itemRadius)

        local dx, dy = x - mx, y - my
        if dx * dx + dy * dy <= itemRadius * itemRadius then
            item.cursorInside = true
        else
            item.cursorInside = false
        end

        x = x + itemRadius + itemRadius + offset
    end
end

function Inventory:draw()
    local x, y = self.x, self.y
    love.graphics.setLineWidth(1)
    
    for pos, item in ipairs(self.items) do
        local radius = itemRadius
        if item.cursorInside then radius = radius * 1.2 end

        if self.enabled and item.isActive then
            love.graphics.setColor(item.item.color or {0.75, 0.75, 0.75, 1})
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        end
        love.graphics.circle('fill', x, y, radius)

        if self.enabled and item.isActive then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        else
            love.graphics.setColor(0.25, 0.25, 0.25, 1)
        end
        love.graphics.circle('line', x, y, radius)

        local w = quantityFont:getWidth(tostring(item.quantity))
        local h = quantityFont:getHeight(tostring(item.quantity))

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setFont(quantityFont)
        PrintText(tostring(item.quantity), x - w/2, y - h/2)

        if item.cursorInside then
            local name = item.item.name
            local description = item.item.description
            local oy = 20
            
            local nameW = quantityFont:getWidth(name)
            local nameH = quantityFont:getHeight(name)

            local descW = quantityFont:getWidth(description)
            local descH = quantityFont:getHeight(description)

            local rectW = math.max(nameW, descW) + 4
            local rectH = nameH + descH + 6
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.rectangle('fill', x, y + oy, rectW, rectH)
            
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle('line', x, y + oy, rectW, rectH)

            love.graphics.setColor(0, 0, 0, 1)
            PrintText(name, x + 2, y + oy + 2)
            PrintText(description, x + 2, y + oy + nameH + 4)
        end

        x = x + itemRadius + itemRadius + offset
    end
end

function Inventory:mousepressed(x, y)
    if not self.enabled then return end

    for pos, item in ipairs(self.items) do
        if item.cursorInside and item.isActive then
            BattleState:set_target_mode(item.item, 'item')
        end
    end
end

return Inventory