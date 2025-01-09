local animation = require 'src.animation'

local multiplier = 1.2

local Cast = Class{}

function Cast:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.x = caster.x + (target.x - caster.x)/2
    self.y = caster.y + (target.y - caster.y)/2

    local dx, dy = target.x - caster.x, target.y - caster.y
    self.r = math.atan2(dy, dx)

    local effect = animation('resources/simplefx-alpha.png', true)
    local x = 0
    local y = 96
    for i = 1, 7 do
        effect:add_frame(x, y, 32, 48)
        x = x + 32
    end
    effect.frameTime = 0.025
    self.timer = 0
    self.effect = effect
end

function Cast:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then
        return false
    end

    -- local damage = self.caster.damage * multiplier
    self.target:take_damage(self.caster, self.damage)

    return true
end

function Cast:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self.effect:draw(self.x, self.y, self.r, 1, 2, self.ox, self.oy)
end

local Claws = Class{}

function Claws:init()
    self.name = 'Claws'
    self.type = 'unit'
    self.range = 1
    self.filter = function(target)
        if target.actor and not target.actor.is_player then
            return true
        end
        return false
    end
    self.element = 'normal'
    self.cost = 2
    self.damage = 10
    self.cast = Cast
end

return Claws