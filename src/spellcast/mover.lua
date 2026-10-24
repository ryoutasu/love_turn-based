local Tween = require 'lib.tween'

local Mover = Class{}

function Mover:init(object, target, duration, easing)
    self.object = object
    self.tween = Tween.new(duration or 1, object, { x = target.x, y = target.y }, easing or 'inCubic')
    
    self.onComplete = function() end
end

function Mover:setOnComplete(func)
    self.onComplete = func
end

function Mover:update(dt)
    -- self.object:update(dt)
    local complete = self.tween:update(dt)

    if complete then
        self:onComplete()
    end
end

function Mover:draw()
    
end

return Mover