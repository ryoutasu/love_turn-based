local Tween = require 'lib.tween'

local FadeOutState = {}

function FadeOutState:init()
end

function FadeOutState:enter(state, args)
    local color = args.color
    local time = args.time
    local onFadeComplete = args.onFadeComplete

    self.r = color.r or color[1]
    self.g = color.g or color[2]
    self.b = color.b or color[3]
    self.opacity = 1
    self.time = time

    self.tween = Tween.new(self.time, self, { opacity = 0 })
    self.onFadeComplete = onFadeComplete or function () end
end

function FadeOutState:update(dt)
    local complete = self.tween:update(dt)
    if complete then
        Gamestate.pop()
        self.onFadeComplete()
    end
end

function FadeOutState:draw()
    UI.setStyle({ draw_border = false, corner_radius = 0 })
    UI.nextPosition("TOPLEFT", "root")
    UI.backdrop("fadeout", 0, 0, love.graphics.getWidth(), love.graphics.getHeight(), "TOPLEFT", { self.r, self.g, self.b, self.opacity })
end

return FadeOutState