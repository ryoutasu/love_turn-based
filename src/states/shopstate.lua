local Inventory = require 'src.levelmap.inventory'
local ItemList = require 'src.items'

local titleFont = love.graphics.newFont(40)
local itemFont = love.graphics.newFont(18)
local currenciesFont = love.graphics.newFont(14)

local itemFillColor = { love.math.colorFromBytes(39, 170, 225) }
local itemLineColor = { love.math.colorFromBytes(20, 140, 200) }
local itemSelectLineColor = { love.math.colorFromBytes(10, 70, 100) }

local bottom_offset_y = 50

local Item = Class{}

local item_w = 400
local item_h = 80

function Item:init(x, y, name, cost, quantity)
    self.item = ItemList[name]
    self.name = name
    self.cost = cost
    self.quantity = quantity

    self.x = x
    self.y = y
    self.w = item_w
    self.h = item_h

    self.cursor_inside = false
end

function Item:update(dt)
    local mx, my = love.mouse.getPosition()
    local cursor_inside = false

    if mx >= self.x and mx < self.x + self.w
    and my >= self.y and my < self.y + self.h then
        cursor_inside = true
    end

    if not self.cursor_inside and cursor_inside then
        self.cursor_inside = cursor_inside
    end

    if self.cursor_inside and not cursor_inside then
        self.cursor_inside = cursor_inside
    end
end

function Item:draw()
    love.graphics.setColor(itemFillColor)
    love.graphics.rectangle('fill', self.x, self.y, self.w, self.h)
    
    if self.cursor_inside then
        love.graphics.setColor(itemSelectLineColor)
    else
        love.graphics.setColor(itemLineColor)
    end
    love.graphics.rectangle('line', self.x, self.y, self.w, self.h)

    local text = self.item.name .. ' : ' .. self.cost .. ' / ' .. self.quantity
    local w, h = itemFont:getWidth(text), itemFont:getHeight()
    local x, y = self.x + self.w/2 - w/2, self.y + self.h/2 - h/2
    
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(itemFont)
    PrintText(text, x, y)
end

local ShopState = Class{}

function ShopState:init()
    self.inventory = Inventory(100, 10)
    local u = Urutora:new()
    
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    
    local w, h = 250, 100
    local x, y = windowWidth/2 - w/2, windowHeight - h - bottom_offset_y
    local backButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Exit'
    }):action(function (e)
        Gamestate.pop()
    end)

    u:add(backButton)

    self.backButton = backButton

    self.u = u

    self.items = {}
end

function ShopState:enter(from, args)
    self.player = args.player

    self.inventory:setup(self.player.inventory)

    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    
    self.items = {
        Item(windowWidth/2 - item_w/2, 120, 'catcher', 20, 1),
        Item(windowWidth/2 - item_w/2, 220, 'healPotion', 20, 2),
        Item(windowWidth/2 - item_w/2, 320, 'energyPotion', 20, 2),
        Item(windowWidth/2 - item_w/2, 420, 'powerup', 20, 2),
    }
end

function ShopState:leave()
    
end

function ShopState:update(dt)
    for index, item in ipairs(self.items) do
        item:update(dt)
    end

    self.u:update(dt)
    self.inventory:update(dt)
end

function ShopState:draw_currencies()
    local padding = 4
    local w, h = self.inventory.w, self.inventory.h
    local x, y = self.inventory.x + w + 10, self.inventory.y
    for name, value in pairs(self.player.currencies) do
        local text = name .. ': ' .. tostring(value)
        local textW = currenciesFont:getWidth(text) + padding + padding
        local textH = currenciesFont:getHeight(text) + padding + padding
    
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, textW, textH)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', x, y, textW, textH)

        love.graphics.setFont(currenciesFont)
        love.graphics.setColor(0, 0, 0, 1)
        PrintText(text, x + padding, y + padding)

        x = x + textW + 10
    end

    return x, y
end

function ShopState:draw()
    local w = titleFont:getWidth('Shop')
    local x, y = love.graphics.getWidth()/2 - w/2, 30
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 1)
    PrintText('Shop', x + 3, y + 3)
    love.graphics.setColor(1, 1, 1, 1)
    PrintText('Shop', x, y)
    
    for index, item in ipairs(self.items) do
        item:draw()
    end
    
    self.u:draw()
    self.inventory:draw()

    self:draw_currencies()
end

function ShopState:mousepressed(x, y, button)
    if button == 1 then
        for index, item in ipairs(self.items) do
            if item.cursor_inside then
                if self.player.currencies.gold >= item.cost and item.quantity > 0 then
                    item.quantity = item.quantity - 1

                    self.player:addItem(item.name, 1)
                    self.player:addCurrency('gold', -item.cost)

                    PlaySound(CoinsSound)
                end
            end
        end
    end

    self.u:pressed(x, y, button)
    self.inventory:mousepressed()
end

function ShopState:mousereleased(x, y, button) self.u:released(x, y) end
function ShopState:keypressed(key, scancode, isrepeat) self.u:keypressed(key, scancode, isrepeat) end
function ShopState:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
function ShopState:textinput(text) self.u:textinput(text) end
function ShopState:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return ShopState