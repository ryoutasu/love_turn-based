local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local color1 = { 0, 0, 1 }
local color2 = { 0.3, 0.75, 1 }
local color3 = { 1, 1, 1 }
local color4 = { 1, 1, 1, 0 }

local speed = 75
return {
    name = 'Splash',
    type = 'unit',
    range = 5,
    filter = TargetFactory.enemy,
    element = 'water',
    cost = 3,
    cooldown = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local dx, dy = caster.x - target.x, caster.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)

        local particle = ParticleEffect(caster.x, caster.y, {
            emissionRate = 1000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.07, size = 2, colors = { color1, color2, color3, color4 }
        })
        local mover = Mover(particle, target, len / speed, 'inCubic')
        
        local particle2 = ParticleEffect(caster.x, caster.y, {
            emissionRate = 2500, distribution = 'borderellipse', dx = 4, dy = 4,
            min = 0.06, max = 0.1, size = 2, colors = { color2, color3, color4 }
        })
        local mover2 = Mover(particle2, target, len / speed, 'inCubic')

        mover:setOnComplete(function ()
            particle:remove()
            particle2:remove()

            local particle3 = ParticleEffect(caster.x, caster.y, {
                emissionRate = 3500, distribution = 'borderellipse', dx = 7, dy = 7,
                min = 0.4, max = 0.6, size = 2, colors = { color1, color2, color3, color4 }
            })
            particle3.system:setRadialAcceleration(150, 200)
            particle3.system:emit(300)
            particle3:remove()

            spellcast:dealDamage(target)

            spellcast:complete()
        end)

        spellcast:addEffect(mover)
        spellcast:addEffect(mover2)
        spellcast:addEffect(particle)
        spellcast:addEffect(particle2)
    end
}