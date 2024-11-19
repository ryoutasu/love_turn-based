local Characters = require 'src.characters'
local Sprite = require 'src.sprite'

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
    self.cx = cx
    self.cy = cy
    self.w = frameWidth
    self.h = frameHeight
    self.font = defualtFont
    self.name = name or ''
    self.cursorInside = false
    self.selected = false

    local character = Characters[name]
    local sprite = Sprite('resources/'.. character.sprite_path ..'.png')
    local rect = character.rect
    local quad = love.graphics.newQuad(0, 0, rect[1], rect[2], rect[3], rect[4])

    self.sprite = sprite
    self.quad = quad
    self.scale = 1
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
        self.scale = 1.2
    end

    if not cursorInside and self.cursorInside then
        self.x = self.sx
        self.y = self.sy
        self.w = frameWidth
        self.h = frameHeight
        self.font = defualtFont
        self.cursorInside = false
        self.scale = 1
    end
end

function Frame:draw()
    love.graphics.setColor(frameFillColor)
    love.graphics.rectangle('fill', self.x, self.y, self.w, self.h)
    if self.selected then
        love.graphics.setLineWidth(4)
        love.graphics.setColor(frameSelectLineColor)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(frameLineColor)
    end
    love.graphics.rectangle('line', self.x, self.y, self.w, self.h)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(self.font)
    love.graphics.print(self.name, self.x + 10, self.y + 10)

    love.graphics.setColor(1, 1, 1, 1)
    local x, y = self.cx - self.sprite.w / 2 * self.scale, self.cy - self.sprite.h / 2 * self.scale + 50
    self.sprite:draw(_, x, y, 0, self.scale, self.scale)

    love.graphics.setLineWidth(1)
end

local CharacterSelect = Class{}

function CharacterSelect:init()
    local u = Urutora:new()

    local seedLabel = u.label({
        x = 0, y = 0,
        w = 60, h = 20,
        text = 'Seed:',
        align = 'left'
    })

    local seedText = u.text({
        x = 70, y = 0,
        w = 110, h = 20,
        text = tostring(os.time()),
        align = 'right'
    })

    u:add(seedLabel)
    u:add(seedText)

    self.seedText = seedText

    self.u = u
end

function CharacterSelect:enter()
    -- bad seeds:
    -- self.seedText.text = tostring(1730817105)
    -- self.seedText.text = tostring(1730817753)
    -- self.seedText.text = tostring(1730817859)
    -- 1730817996
    -- self.seedText.text = tostring(1730818012)
    -- self.seedText.text = tostring(1730824587)
    -- self.seedText.text = tostring(1730824867)
    self.seedText.text = tostring(os.time())

    self.frames = {}

    local frame_1 = Frame(320, frameY, 'Leafen')
    local frame_2 = Frame(640, frameY, 'Emberpuff')
    local frame_3 = Frame(960, frameY, 'Dewscale')

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
        print('Seed: ' .. self.seedText.text)
        Gamestate.switch(Levelmap, { seed = tonumber(self.seedText.text), character = self.selectedFrame.name })
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
    local selectedFrame
    for _, frame in ipairs(self.frames) do
        if frame.cursorInside then
            selectedFrame = frame
            self.selectButton:enable()
        end
    end

    if selectedFrame and selectedFrame ~= self.selectedFrame then
        if  self.selectedFrame then
            self.selectedFrame.selected = false
        end
        selectedFrame.selected = true
        self.selectedFrame = selectedFrame
    end

    -- if not self.selectedFrame then
    --     self.selectButton:disable()
    -- end
end

function CharacterSelect:mousereleased(x, y, button)
    self.u:released(x, y, button)
end

-- function CharacterSelect:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
function CharacterSelect:textinput(text) self.u:textinput(text) end
function CharacterSelect:keypressed(...) self.u:keypressed(...) end
-- function CharacterSelect:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return CharacterSelect