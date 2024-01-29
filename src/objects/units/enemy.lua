local unit = require 'src.objects.unit'

local Enemy = Class{}
Enemy.include(unit)

function Enemy:init(node, sprite, w, h, sw, sh)
    unit.init(self, node, sprite, w, h, sw, sh, false)
    
end

function Enemy:update(dt)
    unit.update(self, dt)
end

function Enemy:draw()
    unit.draw(self)
end

return Enemy