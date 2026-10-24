local Animation = require 'src.animation'

local Effect = Class{}

function Effect:init(animation, params)
    self.animation = animation

    self.x = params.x or 0
    self.y = params.y or 0
    self.r = params.r or 0
    self.sx = params.sx or 1
    self.sy = params.sy or 1
    self.ox = params.ox or 0
    self.oy = params.oy or 0
    self.color = params.color or { 1, 1, 1, 1 }

    self.onComplete = params.onComplete or function() end
end

function Effect:setOnComplete(func)
    self.onComplete = func
end

function Effect:update(dt)
    self.animation:update(dt)

    if self.animation.completed then
        self:onComplete()
    end
end

function Effect:draw()
    love.graphics.setColor(self.color)
    self.animation:draw(self.x, self.y, self.r, self.sx, self.sy, self.ox, self.oy)
    love.graphics.setColor(1, 1, 1, 1)
end

return Effect