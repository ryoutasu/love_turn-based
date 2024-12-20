local CharacterList = require 'src.characterList'

local RestState = Class{}

local centerOffsetX = 50
local centerOffsety = 25

function RestState:init()
    self.characterList = CharacterList(10, 10)

    local u = Urutora:new()

    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    
    local w, h = 300, 200
    local x, y = windowWidth/2 - w - centerOffsetX, windowHeight/2 - h - centerOffsety
    local restButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Rest'
    }):action(function (e)
        self:rest()
    end)

    x, y = windowWidth/2 - w/2, windowHeight/2 + centerOffsety
    local backButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Back'
    }):action(function (e)
        Gamestate.pop({ complete = self.complete })
    end):disable()

    u:add(restButton)
    u:add(backButton)

    self.restButton = restButton
    self.backButton = backButton

    self.u = u

    self.complete = false
end

function RestState:enter(from, args)
    self.restButton:enable()
    self.backButton:disable()

    self.complete = false
    self.player = args.player

    self.characterList:setup(self.player.party)
end

function RestState:rest()
    for i, character in ipairs(self.player.party) do
        character.health = math.min(character.health + character.max_health * 0.35, character.max_health)
    end

    self.restButton:disable()
    self.backButton:enable()
    self.complete = true
end

function RestState:update(dt)
    self.u:update(dt)
    self.characterList:update(dt)
end

function RestState:draw()
    self.u:draw()
    self.characterList:draw()
end

function RestState:mousepressed(x, y, button) self.u:pressed(x, y, button) end
function RestState:mousereleased(x, y, button) self.u:released(x, y) end
function RestState:keypressed(key, scancode, isrepeat) self.u:keypressed(key, scancode, isrepeat) end
function RestState:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
function RestState:textinput(text) self.u:textinput(text) end
function RestState:wheelmoved(x, y) self.u:wheelmoved(x, y) end


return RestState