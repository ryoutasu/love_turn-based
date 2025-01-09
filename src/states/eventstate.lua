local Events = require 'src.events'

local EventState = Class{}

function EventState:init()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()

    local u = Urutora:new()

    local w, h = windowWidth / 2 - 20, windowHeight / 2
    local x, y = 75, windowHeight / 2 - h / 2
    local textLabel = u.label{
        x = x, y = y,
        w = w, h = h,
        'Lorem ipsum dolor sit amet',
        align = 'center'
    }

    u:add(textLabel)

    self.textLabel = textLabel

    self.u = u

    self.currentStep = 0
    self.buttons = {}
end

function EventState:enter(from, args)
    self.type = args.node.type
    self.player = args.player

    -- for i, button in ipairs(self.buttons) do
    --     self.u:remove(button)
    -- end
    -- self.buttons = {}

    local steps = Events.buyItem(args.player)
    self.steps = steps

    self:setupStep(1)
end

function EventState:setupStep(step)
    step = step or 0
    if step == 0 then Gamestate.pop(); return end

    self.currentStep = step

    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()

    for i, button in ipairs(self.buttons) do
        self.u:remove(button)
    end

    self.textLabel.text = self.steps[self.currentStep].text

    local n = #self.steps[self.currentStep].buttons
    local w, h = 200, 60
    local width = (n - 1) * (h + 10)
    for i, button in ipairs(self.steps[self.currentStep].buttons) do
        local x = windowWidth * 3 / 4 - w / 2
        local y = windowHeight / 2 - h / 2 - width / 2 + (i-1) * (h + 20)

        local b = Urutora.button{
            x = x, y = y,
            w = w, h = h,
            text = button.text,
            align = 'center'
        }:action(function ()
            self:setupStep(button.action())
        end)

        self.u:add(b)

        table.insert(self.buttons, b)
    end
end

function EventState:update(dt)
    self.u:update(dt)
end

function EventState:draw()
    self.u:draw()
end

function EventState:mousepressed(x, y, button) self.u:pressed(x, y, button) end
function EventState:mousereleased(x, y, button) self.u:released(x, y) end
function EventState:keypressed(key, scancode, isrepeat) self.u:keypressed(key, scancode, isrepeat) end
function EventState:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
function EventState:textinput(text) self.u:textinput(text) end
function EventState:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return EventState