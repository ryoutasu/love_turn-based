local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Attack = Class{}
Attack:include(action)

local attack_time = 0.25
local back_time = 0.4
function Attack:init(actor, target)
    action.init(self, actor)

    self.target = target
    self.tween = tween.new(attack_time, actor, { x = target.x, y = target.y }, 'inBack')
    self.attacking = true
    target.node.can_be_attacked = false

    Tagtext:add('Attack', self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function Attack:update(dt)
    local complete = self.tween:update(dt)
    if not complete then return false end

    if self.attacking then
        self.tween = tween.new(back_time, self.actor, { x = self.actor.node.x, y = self.actor.node.y }, 'outSine')
        self.attacking = false

        self.target:take_damage(self.caster, self.actor.damage)
    else
        self.target.node:set_animation()
        return true
    end

    return false
end

return Attack