local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Damage = Class{}
Damage:include(action)
Damage.name = 'Damage'

local anim_time = 0.6
local anim_speed = 50
local anim_strength = 12

function Damage:init(actor)
    action.init(self, actor)
end

function Damage:start()
    self.time = 0
end

function Damage:update(dt)
    self.time = self.time + dt
    if self.time >= anim_time then
        if self.actor.health <= 0 then
            BattleState:add_action('faint', self.actor)
        end
        return true
    end
    local offset = math.sin(self.time * anim_speed) * anim_strength * (1 - self.time / anim_time)
    self.actor.x = self.actor.tile.x + offset

    return false
end

return Damage