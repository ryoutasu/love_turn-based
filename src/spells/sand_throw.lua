local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local color1 = { 0.8, 0.7, 0.5 }
local color2 = { 0.9, 0.8, 0.6 }
local color3 = { 1, 1, 1 }
local color4 = { 1, 1, 1, 0 }

local speed = 750
return {
    name = 'Sand Throw',
    type = 'unit',
    range = 1,
    filter = TargetFactory.enemy,
    element = 'neutral',
    cost = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local dx, dy = caster.x - target.x, caster.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)
        local angle = Vector(dx, dy):angleTo()

        local particle = ParticleEffect(caster.x, caster.y, {
            emissionRate = 4000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.08, size = 2, colors = { color1, color2, color3, color4 },
            angle = angle
        })
        particle.system:setLinearAcceleration(0, 200, 0, 400)
        particle.system:setSpeed(100, 200)

        local mover = Mover(particle, target, len / speed, 'linear')

        mover:setOnComplete(function ()
            particle.system:pause()
            particle:remove()
            
            -- Через модификатор, а не прямой записью в поле: иначе бонус
            -- не проходит через Stats и не снимается корректно.
            target:addModifier({
                id = 'sand_throw_miss',
                name = 'Blinded',
                scope = 'battle',
                stat = 'miss_chance',
                op = 'add',
                value = 0.25,
                duration = { type = 'turn', value = 5 },
                stack = 'refresh',
            })

            spellcast:complete()
        end)

        spellcast:addEffect(mover)
        spellcast:addEffect(particle)
    end
}