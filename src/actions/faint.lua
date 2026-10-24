local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Faint = Class{}
Faint:include(action)
Faint.name = 'Faint'

local anim_time = 0.6
local anim_speed = 50
local anim_strength = 12

function Faint:init(actor)
    action.init(self, actor)
end

function Faint:start()
    self.time = 0
    self.tween = tween.new(anim_time, self.actor, { sprite_sx = 1.35, sprite_sy = -0.55, y = self.actor.y + UNIT_DEAD_OFFSET })
end

function Faint:update(dt)
    local complete = self.tween:update(dt)
    if complete then
        return true
    end

    return false
end

return Faint