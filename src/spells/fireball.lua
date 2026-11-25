local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local speed = 75
return {
    name = 'Fireball',
    type = 'unit',
    range = 4,
    filter = TargetFactory.enemy,
    element = 'ember',
    cost = 4,
    cooldown = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local dx, dy = caster.x - target.x, caster.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)

        local particle = ParticleEffect(caster.x, caster.y, {
            emissionRate = 5000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.08, size = 2, colors = { 1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0 }
        })
        local mover = Mover(particle, target, len / speed, 'inCubic')
        
        local particle2 = ParticleEffect(caster.x, caster.y, {
            emissionRate = 3500, distribution = 'borderellipse', dx = 4, dy = 4,
            min = 0.1, max = 0.15, size = 2, colors = { 1,1,0,1, 1,0,0,1, 1,0,0,0 }
        })
        local mover2 = Mover(particle2, target, len / speed, 'inCubic')

        mover:setOnComplete(function ()
            particle:remove()
            particle2:remove()

            local particle3 = ParticleEffect(caster.x, caster.y, {
                emissionRate = 3500, distribution = 'borderellipse', dx = 7, dy = 7,
                min = 0.4, max = 0.6, size = 2, colors = { 1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0 }
            })
            particle3.system:setRadialAcceleration(150, 200)
            particle3.system:emit(800)
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