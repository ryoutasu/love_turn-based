local Sprite = require 'src.sprite'

local window_center_x
local window_center_y

local screenCenterY

local spriteScale = 0.6
local frameSize = 140 * spriteScale
local frameOffset = 16

local frameBackgrondColor = { 0.75, 0.75, 0.75, 0.75 }
local frameLockedBackgrondColor = { 0.5, 0.5, 0.5, 0.75 }
local frameLineColor = { 0.85, 0.85, 0.85 }
local frameLineCursorInsideColor = { 1, 1, 1 }
local framePressedGreenColor = { 0.55, 1, 0.55 }
local framePressedRedColor = { 1, 0.55, 0.55 }

local framePressedTimer = 0.12

local framesRows = 4
local framesCols = 5
local frameWidth
local framesHeight
local framesStartY

local buttonFont = love.graphics.newFont(20)
local buttonFontHeight = buttonFont:getHeight()
local buttonTextPadding = (frameSize - buttonFontHeight) / 2

local buttonsRows = 3

local lineHeight = 400
local lineStartY

local Frame = Class{}

function Frame:init(x, y, index, player, source, locked)
    self.x = x
    self.y = y

    self.cursorInside = false
    self.selected = false

    self.index = index
    self.player = player
    self.source = source

    self.pressedTimer = 0
    self.backgroundColor = frameBackgrondColor

    self.locked = locked or false
end

function Frame:pressed()
    self.pressedTimer = framePressedTimer

    if not self.source[self.index] then
        self.backgroundColor = framePressedRedColor
        return
    end

    local player = self.player
    local from = self.source

    local to = player.charactersActive
    if from == player.charactersActive then
        to = player.charactersStables
    end

    if to == player.charactersActive and #player.charactersActive == player.charactersActiveSize then
        self.backgroundColor = framePressedRedColor
        return
    end

    table.insert(to, self.source[self.index])
    table.remove(from, self.index)
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
    local mx, my = love.mouse.getPosition()

    if self.source[self.index] then
        local character = self.source[self.index]
        love.graphics.setColor(1, 1, 1, 1)
        local sprite = character.sprite
        local sprite_x = x - sprite.w * spriteScale / 2 + frameSize / 2
        local sprite_y = y - sprite.h * spriteScale / 2 + frameSize / 2
        sprite:draw(character.quad, sprite_x, sprite_y, 0, spriteScale, spriteScale)
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

local Stables = {}

function Stables:init()
    window_center_x = love.graphics.getWidth() / 2
    window_center_y = love.graphics.getHeight() / 2
    
    self.frames = {}
    self.buttons = {}

    self.selected = nil
    self.selectedFrame = nil
end

function Stables:enter(state, args)
    self.player = args.player
    self.frames = {}
    self.buttons = {}
    
    local w = frameSize * 6 + frameOffset * 6
    -- local x = window_center_x - frameSize * 2 - frameOffset * 2 - frameSize / 2
    local x = window_center_x - w / 2
    local y = 70

    for i = 1, 4 do
        local locked = i > self.player.charactersActiveSize
        local frame = Frame(x, y, i, self.player, self.player.charactersActive, locked)
        table.insert(self.frames, frame)

        x = x + frameSize + frameOffset
    end
    
    x = x + frameOffset

    for i = 1, 2 do
        local locked = i > self.player.charactersSpareSize
        local frame = Frame(x, y, i, self.player, self.player.charactersSpare, locked)
        table.insert(self.frames, frame)

        x = x + frameSize + frameOffset
    end

    screenCenterY = window_center_y + 20

    frameWidth = frameSize * framesCols + frameOffset * (framesCols - 1)
    framesHeight = frameSize * framesRows + frameOffset * (framesRows - 1)
    framesStartY = screenCenterY - framesHeight / 2
    local x_start = window_center_x + (window_center_x - frameWidth) / 2
    y = framesStartY

    local index = 1
    for i = 1, framesRows do
        x = x_start
        for j = 1, framesCols do
            local frame = Frame(x, y, index, self.player, self.player.charactersStables)
            table.insert(self.frames, frame)

            x = x + frameSize + frameOffset
            index = index + 1
        end
        y = y + frameSize + frameOffset
    end

    local buttonsHeight = frameSize * buttonsRows + frameOffset * (buttonsRows - 1)
    
    x = (window_center_x - frameWidth) / 2
    y = screenCenterY - buttonsHeight / 2

    for i = 1, 3 do
        table.insert(self.buttons, Button(x, y, frameWidth, frameSize, self.player, 'Button '..i))
        y = y + frameSize + frameOffset
    end

    self.buttons[1].text = 'Open additional party slot'
    self.buttons[1].cost = 200
    self.buttons[1].action = function ()
        self.player.charactersActiveSize = math.min(self.player.charactersActiveSize + 1, 5)
        self.frames[self.player.charactersActiveSize].locked = false
        if self.player.charactersActiveSize == 5 then self.buttons[1].active = false end
    end

    lineHeight = love.graphics.getHeight() / 2
    lineStartY = screenCenterY - lineHeight / 2

    self.selected = nil
    self.selectedFrameIndex = nil
end

function Stables:update(dt)
    for index, frame in ipairs(self.frames) do
        frame:update(dt)
    end

    for index, button in ipairs(self.buttons) do
        button:update(dt)
    end
end

function Stables:draw()
    local mx, my = love.mouse.getPosition()

    for index, frame in ipairs(self.frames) do
        frame:draw()
        frame:drawSprite()
    end

    for index, button in ipairs(self.buttons) do
        button:draw()
    end

    UI.setStyle()
    UI.setFont(24)
    UI.nextPosition("BOTTOM", "root")
    if UI.button("stables_back", 0, -40, 200, 80, "BACK", "BOTTOM")
    and #self.player.charactersActive > 0 then
        if self.selected then
            self.selectedFrame.source[self.selectedFrame.index] = self.selected
            self.selected = nil
            self.selectedFrame = nil
        end
        Gamestate.pop()
    end
    
    -- self.player:drawCurrency()
    -- self.player:drawCaharacterList()

    if self.selected then
        local sprite = self.selected.sprite
        UI.nextPosition("TOPLEFT", "root")
        UI.image(mx, my, sprite.image, "CENTER", spriteScale)
    end

    x = window_center_x
    y = lineStartY
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y, x, y + lineHeight)

    local w = frameSize * 6 + frameOffset * 6
    local x = window_center_x - w / 2 + frameSize * 4 + frameOffset * 4
    local y = 70
    love.graphics.line(x, y, x, y + frameSize)
end

function Stables:framePressed(frame)
    if frame.locked then return end
    if not self.selected then
        self.selectedFrame = frame
        self.selected = frame.source[frame.index]
        frame.source[frame.index] = nil
    else
        local from = self.selectedFrame

        from.source[from.index] = frame.source[frame.index]
        frame.source[frame.index] = self.selected

        self.selected = nil
        self.selectedFrame = nil
    end
end

function Stables:mousepressed(mx, my, button)
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
end

function Stables:keypressed(key)
    if key == "escape" then
        if self.selected then
            self.selectedFrame.source[self.selectedFrame.index] = self.selected
            self.selected = nil
            self.selectedFrame = nil
        end
    end
end

return Stables