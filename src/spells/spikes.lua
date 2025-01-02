local animation = require 'src.animation'

local multiplier = 1.5

local Spikes = Class{
    name = 'Spikes',
    type = 'unit',
    range = 5,
    filter = function(target)
        if target.actor and not target.actor.is_player then
            return true
        end
        return false
    end,
    element = 'stone',
    cost = 3,
}

function Spikes:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.x = target.x
    self.y = target.y

    local effect = animation('resources/Spikes/1.png', true)
    local x = 0
    local y = 0
    for i = 1, 6 do
        effect:add_frame(x, y, 32, 32)
        x = x + 32
    end
    effect.frameTime = 0.15
    effect.play = true
    self.effect = effect
end

function Spikes:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then
        return false
    end

    local damage = self.caster.damage * multiplier
    self.target:take_damage(self.caster, damage)
    
    return true
end

function Spikes:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self.effect:draw(self.x, self.y, 0, 2, 2, self.ox, self.oy)
end

return Spikes