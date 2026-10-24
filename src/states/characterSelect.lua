local Characters = require 'src.characters'
local Sprite = require 'src.sprite'

local frameFillColor = { love.math.colorFromBytes(39, 170, 225) }
local frameLineColor = { love.math.colorFromBytes(20, 140, 200) }
local frameSelectLineColor = { love.math.colorFromBytes(10, 70, 100) }

local defualtFont = love.graphics.newFont(20)
local bigFont = love.graphics.newFont(24)

local frameY = 300
local frameWidth = 250
local frameHeight = 400

local Frame = Class{}

function Frame:init(cx, cy, name1, name2)
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
    self.name1 = name1 or ''
    self.name2 = name2 or ''
    self.cursorInside = false
    self.selected = false

    local character1 = Characters[name1]
    local sprite1 = Sprite(character1.sprite_path, character1.color)
    local rect1 = character1.rect
    local quad1 = love.graphics.newQuad(0, 0, rect1[1], rect1[2], rect1[3], rect1[4])

    local character2 = Characters[name2]
    local sprite2 = Sprite(character2.sprite_path, character2.color)
    local rect2 = character2.rect
    local quad2 = love.graphics.newQuad(0, 0, rect2[1], rect2[2], rect2[3], rect2[4])

    self.sprite1 = sprite1
    self.quad1 = quad1
    self.sprite2 = sprite2
    self.quad2 = quad2
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

local corner = 10
function Frame:draw()
    love.graphics.setColor(frameFillColor)
    love.graphics.rectangle('fill', self.x, self.y, self.w, self.h, corner, corner)
    if self.selected then
        love.graphics.setLineWidth(4)
        love.graphics.setColor(frameSelectLineColor)
    else
        love.graphics.setLineWidth(2)
        love.graphics.setColor(frameLineColor)
    end
    love.graphics.rectangle('line', self.x, self.y, self.w, self.h, corner, corner)

    love.graphics.setColor(1, 1, 1, 1)
    local x, y = self.x + 20 * self.scale, self.y + 20 * self.scale
    self.sprite1:draw(_, x, y, 0, self.scale, self.scale)

    love.graphics.setColor(1, 1, 1, 1)
    x, y = self.x + self.w - 20 * self.scale - self.sprite2.w * self.scale, self.y + self.h - 20 * self.scale - self.sprite2.w * self.scale
    self.sprite2:draw(_, x, y, 0, self.scale, self.scale)

    -- local textW = self.font:getWidth(self.name1)
    local textH = self.font:getHeight()

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(self.font)
    PrintfText(self.name1, self.x, self.cy - textH / 2 - 4, self.w, 'center')
    PrintfText(self.name2, self.x, self.cy + textH / 2 + 4, self.w, 'center')

    love.graphics.setLineWidth(1)
end

local CharacterSelect = {}

function CharacterSelect:init()

end

function CharacterSelect:enter()
    self.seed = tostring(os.time())

    self.frames = {}

    local frame_1 = Frame(260, frameY, 'Emberpuff', 'Aetheris')
    local frame_2 = Frame(640, frameY, 'Leafen', 'Dewscale')
    local frame_3 = Frame(1020, frameY, 'Terrow', 'Quillpaw')

    table.insert(self.frames, frame_1)
    table.insert(self.frames, frame_2)
    table.insert(self.frames, frame_3)

    self.selectedFrame = nil
end

function CharacterSelect:update(dt)
    for _, frame in ipairs(self.frames) do
        frame:update(dt)
    end
end

function CharacterSelect:draw()
    UI.nextPosition("TOPLEFT", "root")
    UI.text(4, 4, "Seed:", "TOPLEFT")
    UI.nextPosition("RIGHT")
    self.seed = UI.inputText("seed_input", 2, 0, 110, 20, self.seed, "LEFT")

    UI.nextPosition("BOTTOM", "root")
    if UI.button("select_character", 0, -70, 200, 50, "Select", "BOTTOM", self.selectedFrame ~= nil) then
        PlaySound(ButtonClickSound)
        print('Seed: ' .. self.seed)
        Gamestate.push(FadeInState, { color = { r = 1, g = 1, b = 1 }, time = 1, onFadeComplete = function()
            IntroMusic:stop()
            FieldMusic:play()

            Gamestate.switch(TownState, { seed = tonumber(self.seed), characters = { self.selectedFrame.name1, self.selectedFrame.name2 } })
            Gamestate.push(FadeOutState, { color = { r = 1, g = 1, b = 1 }, time = 1 })
        end })
    end

    for _, frame in ipairs(self.frames) do
        frame:draw()
    end
end

function CharacterSelect:mousepressed(x, y, button)
    local selectedFrame
    for _, frame in ipairs(self.frames) do
        if frame.cursorInside then
            selectedFrame = frame
        end
    end

    if selectedFrame and selectedFrame ~= self.selectedFrame then
        if  self.selectedFrame then
            self.selectedFrame.selected = false
        end
        selectedFrame.selected = true
        self.selectedFrame = selectedFrame

        PlaySound(ButtonClickSound)
    end
end

function CharacterSelect:keypressed(key)
    if key == "escape" then
        Gamestate.switch(MainMenuState)
    end
end

return CharacterSelect