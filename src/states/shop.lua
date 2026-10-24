local Sprite = require 'src.sprite'
local ItemList = require 'src.items'

local window_center_x
local window_center_y

local screenCenterY

local shopItemList = {
    { name = 'healPotion', quantity = 4, cost = 20 },
    { name = 'energyPotion', quantity = 3, cost = 20 },
    { name = 'cleansingSalve', quantity = 3, cost = 30 },
    { name = 'catcher', quantity = 1, cost = 20 },
    { name = 'shieldCharm', quantity = 2, cost = 50 },
    { name = 'battleHorn', quantity = 2, cost = 50 },
    { name = 'spikeTrap', quantity = 2, cost = 60 },
}

local spriteScale = 0.6
local frameSize = 60
local frameOffset = 16

local frameTextSize = 12
local frameTextFont = love.graphics.newFont(frameTextSize)
local frameBackgrondColor = { 0.75, 0.75, 0.75, 0.75 }
local frameLockedBackgrondColor = { 0.5, 0.5, 0.5, 0.75 }
local frameLineColor = { 0.85, 0.85, 0.85 }
local frameLineCursorInsideColor = { 1, 1, 1 }
local framePressedGreenColor = { 0.55, 1, 0.55 }
local framePressedRedColor = { 1, 0.55, 0.55 }

local framePressedTimer = 0.12

local framesRows = 5
local framesCols = 4
local frameWidth
local framesHeight
local framesStartY

local buttonFont = love.graphics.newFont(20)
local buttonFontHeight = buttonFont:getHeight()
local buttonTextPadding = (frameSize - buttonFontHeight) / 2

local buttonsRows = 3

local lineHeight = 400
local lineStartY
local lineRightX
local lineLeftX

local Frame = Class{}

function Frame:init(x, y, index, source, locked)
    self.x = x
    self.y = y

    self.cursorInside = false
    self.selected = false

    self.index = index
    self.source = source

    self.pressedTimer = 0
    self.backgroundColor = frameBackgrondColor

    self.locked = locked or false

    self.action = nil
end

function Frame:pressed()
    self.pressedTimer = framePressedTimer
    
    if not self.action(self) then
        self.backgroundColor = framePressedRedColor
        return
    end
    
    self.backgroundColor = framePressedGreenColor
end

function Frame:update(dt)
    local mx, my = love.mouse.getPosition()

    local w, h = frameSize, frameSize
    local x, y = self.x, self.y

    self.cursorInside = mx >= x and mx <= x + w and my >= y and my <= y + h
    
    if self.pressedTimer > 0 then
        self.pressedTimer = self.pressedTimer - dt
        if self.pressedTimer <= 0 then
            self.backgroundColor = frameBackgrondColor
            self.pressedTimer = 0
        end
    end
end

function Frame:drawSprite()
    local x, y = self.x, self.y

    if self.source[self.index] then
        local item = self.source[self.index]

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(frameTextFont)
        -- love.graphics.print(item.item.name, x, y)
        PrintfText(item.item.name, x + 2, y + 1, frameSize, 'left')
        PrintfText(tostring(item.quantity), x + 2, y + frameSize - frameTextFont:getHeight() - 1, frameSize, 'left')
        if item.cost then
            love.graphics.setColor(1, 215/255, 0, 1)
            PrintfText(tostring(item.cost), x, y + frameSize - frameTextFont:getHeight() - 1, frameSize - 4, 'right')
        end
    end
end

function Frame:draw()
    local x, y = self.x, self.y

    if self.locked then
        love.graphics.setColor(frameLockedBackgrondColor)
    else
        if self.selected then
            love.graphics.setColor(framePressedGreenColor)
        else
            love.graphics.setColor(self.backgroundColor)
        end
    end
    love.graphics.rectangle('fill', x, y, frameSize, frameSize)

    if self.cursorInside then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(frameLineCursorInsideColor)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(frameLineColor)
    end
    love.graphics.rectangle('line', x, y, frameSize, frameSize)
end

local Button = Class{}

function Button:init(x, y, w, h, player, text, cost)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    
    self.cursorInside = false

    self.player = player

    self.pressedTimer = 0
    self.backgroundColor = frameBackgrondColor

    self.text = text
    self.cost = cost or 0

    self.active = true
end

function Button:pressed()
    self.pressedTimer = framePressedTimer

    if not self.active then return end

    if self.player.currencies.gold < self.cost then
        self.backgroundColor = framePressedRedColor
        return
    end
    
    self.player:addCurrency('gold', -self.cost)

    if self.action then
        self.action()
    end
    
    self.backgroundColor = framePressedGreenColor
end

function Button:update(dt)
    local mx, my = love.mouse.getPosition()

    local x, y = self.x, self.y
    local w, h = self.w, self.h

    self.cursorInside = mx >= x and mx <= x + w and my >= y and my <= y + h
    
    if self.pressedTimer > 0 then
        self.pressedTimer = self.pressedTimer - dt
        if self.pressedTimer <= 0 then
            self.backgroundColor = frameBackgrondColor
            self.pressedTimer = 0
        end
    end
end

function Button:draw()
    local x, y = self.x, self.y
    local w, h = self.w, self.h
    if not self.active then
        love.graphics.setColor(frameLockedBackgrondColor)
    else
        love.graphics.setColor(self.backgroundColor)
    end
    love.graphics.rectangle('fill', x, y, w, h)

    if self.text then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(buttonFont)
        PrintText(self.text, x + buttonTextPadding, y + buttonTextPadding)
    end
    
    if self.cost then
        love.graphics.setColor(1, 215/255, 0, 1)
        love.graphics.setFont(buttonFont)
        PrintfText(self.cost, x + buttonTextPadding, y + buttonTextPadding, frameWidth - buttonTextPadding - buttonTextPadding, 'right')
    end

    if self.cursorInside then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(frameLineCursorInsideColor)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(frameLineColor)
    end
    love.graphics.rectangle('line', x, y, w, h)
end

local Shop = {}

function Shop:init()
    window_center_x = love.graphics.getWidth() / 2
    window_center_y = love.graphics.getHeight() / 2
    
    self.frames = {}
    self.buttons = {}

    self.shopItems = {}
    self.refreshed = false

    self.selected = nil
    self.selectedFrame = nil
end

function Shop:enter(state, args)
    self.player = args.player
    self.frames = {}
    self.buttons = {}

    local player = self.player

    if not self.refreshed then
        self:refreshItems()
    end
    
    local x = window_center_x - frameSize * 2 - frameOffset * 2 - frameSize / 2
    local y = 70

    for i = 1, 5 do
        local locked = i > player.inventorySize
        local frame = Frame(x, y, i, player.inventory, locked)
        table.insert(self.frames, frame)

        frame.action = function ()
            if not player.inventory[frame.index] then
                return false
            end

            table.insert(player.store, player.inventory[frame.index])
            table.remove(player.inventory, frame.index)
            return true
        end

        x = x + frameSize + frameOffset
    end

    screenCenterY = window_center_y + 20
    
    frameWidth = frameSize * framesCols + frameOffset * (framesCols - 1)
    framesHeight = frameSize * framesRows + frameOffset * (framesRows - 1)
    framesStartY = screenCenterY - framesHeight / 2
    -- local x_start = window_center_x + (window_center_x - frameWidth) / 2
    local window_third = love.graphics.getWidth() / 3

    -- SHOP
    local x_start = window_third + (window_third - frameWidth) / 2
    y = framesStartY

    local index = 1
    for i = 1, framesRows do
        x = x_start
        for j = 1, framesCols do
            local item = self.shopItems[index]
            local frame = Frame(x, y, index, self.shopItems)
            table.insert(self.frames, frame)

            frame.action = function ()
                if not item then
                    return false
                end
                if player.currencies['gold'] < (item.cost or 0) then
                    return false
                end
                if item.quantity <= 0 then
                    return false
                end

                player:addCurrency('gold', -item.cost)
                player:addItem(item.item, 1)
                item.quantity = item.quantity - 1
                return true
            end

            x = x + frameSize + frameOffset
            index = index + 1
        end
        y = y + frameSize + frameOffset
    end

    -- STORE
    x_start = window_third + window_third + (window_third - frameWidth) / 2
    y = framesStartY

    index = 1
    for i = 1, framesRows do
        x = x_start
        for j = 1, framesCols do
            local frame = Frame(x, y, index, self.player.store)
            table.insert(self.frames, frame)

            frame.action = function ()
                if not player.store[frame.index] then
                    return false
                end
                if #player.inventory >= player.inventorySize then
                    return false
                end

                table.insert(player.inventory, player.store[frame.index])
                table.remove(player.store, frame.index)
                return true
            end

            x = x + frameSize + frameOffset
            index = index + 1
        end
        y = y + frameSize + frameOffset
    end

    -- UPGRADES
    local buttonsHeight = frameSize * buttonsRows + frameOffset * (buttonsRows - 1)
    
    x = (window_third - frameWidth) / 2
    y = screenCenterY - buttonsHeight / 2

    for i = 1, 3 do
        table.insert(self.buttons, Button(x, y, frameWidth, frameSize, self.player, 'Button '..i))
        y = y + frameSize + frameOffset
    end

    self.buttons[1].text = 'Open additional inventory slot'
    self.buttons[1].cost = 100
    self.buttons[1].action = function ()
        self.player.inventorySize = math.min(self.player.inventorySize + 1, 5)
        self.frames[self.player.inventorySize].locked = false
        if self.player.inventorySize == 5 then self.buttons[1].active = false end
    end

    lineHeight = love.graphics.getHeight() / 2
    lineStartY = screenCenterY - lineHeight / 2
    lineRightX = love.graphics.getWidth() / 3
    lineLeftX = love.graphics.getWidth() * 2 / 3

    self.selected = nil
    self.selectedFrame = nil
end

function Shop:refreshItems()
    self.shopItems = {}

    for index, item in ipairs(shopItemList) do
        if ItemList[item.name] then
            table.insert(self.shopItems, { item = ItemList[item.name], quantity = item.quantity, cost = item.cost })
        end
    end

    self.refreshed = true
end

function Shop:update(dt)
    for index, frame in ipairs(self.frames) do
        frame:update(dt)
    end

    for index, button in ipairs(self.buttons) do
        button:update(dt)
    end
end

local font = love.graphics.newFont(24)
function Shop:draw()
    local mx, my = love.mouse.getPosition()

    for index, frame in ipairs(self.frames) do
        frame:draw()
        frame:drawSprite()
    end

    for index, button in ipairs(self.buttons) do
        button:draw()
    end

    UI.setStyle()
    UI.setFont(font)
    UI.nextPosition("BOTTOM", "root")
    if UI.button("stables_back", 0, -40, 200, 80, "BACK", "BOTTOM") then
        if self.selected then
            self:deselectItem()
        end
        Gamestate.pop()
    end

    -- self.player:drawCurrency()

    x = window_center_x
    y = lineStartY
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(lineRightX, y, lineRightX, y + lineHeight)
    love.graphics.line(lineLeftX, y, lineLeftX, y + lineHeight)
    
    if self.selected then
        local item = self.selected

        x = mx - frameSize / 2
        y = my - frameSize / 2

        love.graphics.setColor(frameBackgrondColor)
        love.graphics.rectangle('fill', x, y, frameSize, frameSize)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(frameTextFont)
        PrintfText(item.item.name, x + 2, y + 1, frameSize, 'left')
        PrintfText(tostring(item.quantity), x + 2, y + frameSize - frameTextFont:getHeight() - 1, frameSize, 'left')
        if item.cost then
            love.graphics.setColor(1, 215/255, 0, 1)
            PrintfText(tostring(item.cost), x, y + frameSize - frameTextFont:getHeight() - 1, frameSize - 4, 'right')
        end
    end
end

function Shop:deselectItem()
    if not self.selectedFrame then
        self.player:addItem(self.selected.item, self.selected.quantity)
    else
        local item = self.selectedFrame.source[self.selectedFrame.index]
        if item then
            local add = math.min(5 - item.quantity, self.selected.quantity)

            item.quantity = item.quantity + add
            self.selected.quantity = self.selected.quantity - add
            if self.selected.quantity > 0 then
                self.player:addItem(self.selected.item, self.selected.quantity)
            end
        else
            self.selectedFrame.source[self.selectedFrame.index] = self.selected
        end
    end
    self.selected = nil
    self.selectedFrame = nil
end

function Shop:framePressed(frame)
    if frame.locked then return end
    if frame.source == self.shopItems then
        local item = self.shopItems[frame.index]
        local player = self.player
        if not item then
            return false
        end
        if player.currencies['gold'] < (item.cost or 0) then
            return false
        end
        if item.quantity <= 0 then
            return false
        end

        player:addCurrency('gold', -item.cost)
        -- player:addItem(item.item, 1)

        if self.selected then
            if item.item.name == self.selected.item.name and self.selected.quantity < 5 then
                self.selected.quantity = self.selected.quantity + 1
            else
                player:addItem(item.item, 1)
            end
        else
            self.selected = { item = item.item, quantity = 1, isActive = true }
        end

        item.quantity = item.quantity - 1
        return true
    end

    if not self.selected then
        self.selectedFrame = frame
        self.selected = frame.source[frame.index]
        frame.source[frame.index] = nil
    else
        local from = self.selectedFrame
        local item = frame.source[frame.index]
        local itemSelected = self.selected
        
        if item and item.item.name == itemSelected.item.name
        and item.quantity < 5 then
            local add = math.min(5 - item.quantity, itemSelected.quantity)
            item.quantity = item.quantity + add
            itemSelected.quantity = itemSelected.quantity - add

            if itemSelected.quantity > 0 then
                if not from then
                    self.player:addItem(self.selected.item, self.selected.quantity)
                else
                    from.source[from.index] = self.selected
                end
            end
            
            self.selected = nil
            self.selectedFrame = nil

            return
        else
            if frame.source[frame.index] then
                from.source[from.index] = frame.source[frame.index]
            end
            frame.source[frame.index] = self.selected
        end

        self.selected = nil
        self.selectedFrame = nil
    end
end

function Shop:divideFrame(frame)
    if frame.locked then return end
    if frame.source == self.shopItems then
        local item = self.shopItems[frame.index]
        local player = self.player
        if not item then
            return false
        end
        if player.currencies['gold'] < (item.cost or 0) then
            return false
        end
        if item.quantity <= 0 then
            return false
        end

        player:addCurrency('gold', -item.cost)
        player:addItem(item.item, 1)
        item.quantity = item.quantity - 1
        return
    end

    local item = frame.source[frame.index]
    if self.selected then
        if item and item.item.name == self.selected.item.name
        and item.quantity < 5 then
            item.quantity = item.quantity + 1

            self.selected.quantity = self.selected.quantity - 1
            if self.selected.quantity <= 0 then
                self.selected = nil
                self.selectedFrame = nil
            end
        end

        if not item then
            frame.source[frame.index] = { item = self.selected.item, quantity = 1, isActive = true }

            self.selected.quantity = self.selected.quantity - 1
            if self.selected.quantity <= 0 then
                self.selected = nil
                self.selectedFrame = nil
            end
        end
    else
        if item then
            self.selected = { item = item.item, quantity = math.ceil(item.quantity / 2), isActive = true }
            item.quantity = item.quantity - self.selected.quantity
            self.selectedFrame = frame

            if item.quantity <= 0 then
                frame.source[frame.index] = nil
            end
        end
    end
end

function Shop:mousepressed(mx, my, button)
    if button == 1 then
        for index, frame in ipairs(self.frames) do
            if frame.cursorInside then
                -- frame:pressed()
                self:framePressed(frame)
            end
        end
        
        for index, button in ipairs(self.buttons) do
            if button.cursorInside then
                button:pressed()
            end
        end
    end

    if button == 2 then
        for index, frame in ipairs(self.frames) do
            if frame.cursorInside then
                self:divideFrame(frame)
            end
        end
    end
end

function Shop:keypressed(key)
    if key == "escape" then
        if self.selected then
            self:deselectItem()
        end
    end
end

return Shop