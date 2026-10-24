local Sprite = require 'src.sprite'

local window_center_x
local window_center_y

local frameSize = 140 * 0.6
local frameOffset = 16

local frameBackgrondColor = { 0.75, 0.75, 0.75, 0.75 }
local frameLockedBackgrondColor = { 0.5, 0.5, 0.5, 0.75 }
local frameLineColor = { 0.85, 0.85, 0.85 }
local frameLineCursorColor = { 1, 1, 1 }
local framePressedGreenColor = { 0.55, 1, 0.55 }
local framePressedRedColor = { 1, 0.55, 0.55 }

local framePressedTimer = 0.12

local framesRows = 3
local framesCols = 5
local framesHeight

local Frame = Class{}

function Frame:init(x, y, index, player, source, locked)
    self.x = x
    self.y = y

    -- if character then
    --     self:setCharacter(character)
    -- end

    self.cursorInside = false
    self.selected = false

    self.index = index
    self.player = player
    self.source = source

    self.pressedTimer = 0
    self.backgroundColor = frameBackgrondColor

    self.locked = locked or false
end

-- function Frame:setCharacter(character, player)
--     -- if not character then
--     --     self.character = nil
--     --     self.sprite = nil
--     --     self.quad = nil
--     --     return
--     -- end
--     -- self.character = character
--     -- self.sprite = Sprite(character.sprite_path, character.color)
--     -- local rect = character.rect
--     -- self.quad = love.graphics.newQuad(0, 0, rect[1], rect[2], rect[3], rect[4])
--     self.character = character
-- end

-- function Frame:setSelected(selected)
--     self.selected = selected
-- end

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
        if #player.charactersActive == 1 then
            self.backgroundColor = framePressedRedColor
            return
        end
        to = player.characters
    end

    -- не более 5 персонажей в группе
    -- точнее, не более максимума (улучшается здесь же)
    if to == player.charactersActive and #player.charactersActive == player.maxPartySize then
        self.backgroundColor = framePressedRedColor
        return
    end

    table.insert(to, self.source[self.index])
    table.remove(from, self.index)
    
    self.backgroundColor = framePressedGreenColor
end

function Frame:update(dt)
    local mx, my = love.mouse.getPosition()

    -- local _, _, w, h = self.quad:getViewport()
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

function Frame:draw()
    local x, y = self.x, self.y

    if self.locked then
        love.graphics.setColor(frameLockedBackgrondColor)
    else
        love.graphics.setColor(self.backgroundColor)
    end
    love.graphics.rectangle('fill', x, y, frameSize, frameSize)

    if self.source[self.index] then
        local character = self.source[self.index]
        love.graphics.setColor(1, 1, 1, 1)
        character.sprite:draw(character.quad, x, y, 0, character.sprite_sx or 1, character.sprite_sy or 1)
    end

    if self.cursorInside then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(frameLineCursorColor)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(frameLineColor)
    end
    love.graphics.rectangle('line', x, y, frameSize, frameSize)
end

local Petshop = Class{}

function Petshop:init()
    window_center_x = love.graphics.getWidth() / 2
    window_center_y = love.graphics.getHeight() / 2
    
end

function Petshop:enter(state, args)
    self.player = args.player
    self.characters = {}
    self.frames = {}
    
    local x = window_center_x - frameSize * 2 - frameOffset * 2 - frameSize / 2
    local y = 70

    for i = 1, 5 do
        local locked = i > self.player.maxPartySize
        local frame = Frame(x, y, i, self.player, self.player.charactersActive, locked)
        table.insert(self.frames, frame)

        x = x + frameSize + frameOffset
    end
    
    local width = frameSize * framesCols + frameOffset * (framesCols - 1)
    framesHeight = frameSize * framesRows + frameOffset * (framesRows - 1)
    -- x = window_center_x - frameSize * 4 - frameOffset * 4 - frameSize / 2
    local x_start = window_center_x + (window_center_x - width) / 2
    y = 70 + frameSize * 2

    local index = 1
    for i = 1, framesRows do
        x = x_start
        for j = 1, framesCols do
            local frame = Frame(x, y, index, self.player, self.player.characters)
            table.insert(self.frames, frame)

            x = x + frameSize + frameOffset
            index = index + 1
        end
        -- x = window_center_x - frameSize * 4 - frameOffset * 4 - frameSize / 2
        y = y + frameSize + frameOffset
    end

    self.selected = nil
end

function Petshop:update(dt)
    for index, frame in ipairs(self.frames) do
        frame:update(dt)
    end
end

function Petshop:draw()
    local mx, my = love.mouse.getPosition()

    for index, frame in ipairs(self.frames) do
        frame:draw()
    end

    local w, h = 200, 80
    local x = window_center_x - w / 2
    local y = love.graphics.getHeight() - h - 40
    love.graphics.setColor(1, 1, 1, 1)
    if mx >= x and my >= y and mx <= x + w and my <= y + h then
        if #self.player.charactersActive > 0 then
            love.graphics.setColor(0.85, 0.85, 0.9, 1)
        else
            love.graphics.setColor(1, 0.65, 0.65, 1)
        end
    end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0, 0, 0, 1)
    PrintfText('B A C K', x, y + 16, w, 'center')

    x = window_center_x
    y = 70 + frameSize * 2
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y, x, y + framesHeight)
end

function Petshop:mousepressed(mx, my, button)
    -- local selected = self.selected
    -- local other = nil

    -- if button == 1 then
    --     for index, frame in ipairs(self.frames) do
    --         frame:setSelected(frame.cursorInside and not frame.selected)

    --         if frame.selected then
    --             other = frame
    --         end
    --     end

    --     if other and selected and other ~= selected then
    --         local otherCharacter = other.character
    --         other:setCharacter(selected.character)
    --         selected:setCharacter(otherCharacter)

    --         other:setSelected(false)
    --         selected:setSelected(false)

    --         other = nil
    --     end
    --     self.selected = other
    -- end

    if button == 1 then
        for index, frame in ipairs(self.frames) do
            if frame.cursorInside then
                frame:pressed()
            end
        end

        local w, h = 200, 80
        local x = window_center_x - w / 2
        local y = love.graphics.getHeight() - h - 40
        if mx >= x and my >= y and mx <= x + w and my <= y + h then
            if #self.player.charactersActive > 0 then
                Gamestate.pop()
            end
        end
    end
end

return Petshop