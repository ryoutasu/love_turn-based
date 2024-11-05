local unit_def = require 'resources.unit_definition'
local frameFillColor = { love.math.colorFromBytes(39, 170, 225) }
local frameLineColor = { love.math.colorFromBytes(20, 140, 200) }
local frameSelectLineColor = { love.math.colorFromBytes(10, 70, 100) }

local defualtFont = love.graphics.newFont(14)
local bigFont = love.graphics.newFont(18)

local frameY = 300
local frameWidth = 200
local frameHeight = 350

local Frame = Class{}

function Frame:init(cx, cy, name)
    local x = cx - frameWidth/2
    local y = cy - frameHeight/2
    self.x = x
    self.y = y
    self.sx = x
    self.sy = y
    self.w = frameWidth
    self.h = frameHeight
    self.font = defualtFont
    self.name = name or ''
    self.cursorInside = false
    self.selected = false
end

function Frame:update(dt)
    local mx, my = love.mouse.getPosition()
    local cursorInside = false

    if mx >= self.x and mx < self.x + self.w
    and my >= self.y and my < self.y + self.h then
        cursorInside = true
    end

    if cursorInside and not self.cursorInside then
        self.x = self.sx - frameWidth * 0.1
        self.y = self.sy - frameHeight * 0.1
        self.w = frameWidth + frameWidth * 0.2
        self.h = frameHeight + frameHeight * 0.2
        self.font = bigFont
        self.cursorInside = true
    end

    if not cursorInside and self.cursorInside then
        self.x = self.sx
        self.y = self.sy
        self.w = frameWidth
        self.h = frameHeight
        self.font = defualtFont
        self.cursorInside = false
    end
end

function Frame:draw()
    love.graphics.setColor(frameFillColor)
    love.graphics.rectangle('fill', self.x, self.y, self.w, self.h)
    if self.selected then
        love.graphics.setColor(frameSelectLineColor)
    else
        love.graphics.setColor(frameLineColor)
    end
    love.graphics.rectangle('line', self.x, self.y, self.w, self.h)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(self.font)
    love.graphics.print(self.name, self.x + 10, self.y + 10)
end

local CharacterSelect = Class{}

function CharacterSelect:init()
    local u = Urutora:new()

    self.u = u
end

function CharacterSelect:enter()
    self.frames = {}

    local frame_1 = Frame(320, frameY, 'Alice')
    local frame_2 = Frame(640, frameY, 'Wizard')
    local frame_3 = Frame(960, frameY, 'Gato')

    table.insert(self.frames, frame_1)
    table.insert(self.frames, frame_2)
    table.insert(self.frames, frame_3)

    local w, h = 200, 50
    local x, y = 640 - w/2, 600
    local selectButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Select',
    }):action(function (e)
        Gamestate.switch(Levelmap, { character = self.selectedFrame.name })
    end):disable()

    self.selectButton = selectButton
    self.u:add(selectButton)
    self.selectedFrame = nil
end

function CharacterSelect:update(dt)
    self.u:update(dt)
    for _, frame in ipairs(self.frames) do
        frame:update(dt)
    end
end

function CharacterSelect:draw()
    self.u:draw()
    for _, frame in ipairs(self.frames) do
        frame:draw()
    end
end

function CharacterSelect:mousepressed(x, y, button)
    self.u:pressed(x, y, button)

    if self.selectButton.pressed then return end

    -- self.selectedFrame = nil

    for _, frame in ipairs(self.frames) do
        frame.selected = frame.cursorInside
        if frame.selected then
            self.selectedFrame = frame
            self.selectButton:enable()
        end
    end

    -- if not self.selectedFrame then
    --     self.selectButton:disable()
    -- end
end

function CharacterSelect:mousereleased(x, y, button)
    self.u:released(x, y, button)
end

-- function CharacterSelect:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
-- function CharacterSelect:textinput(text) self.u:textinput(text) end
-- function CharacterSelect:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return CharacterSelect