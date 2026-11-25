local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local speed = 350
return {
    name = 'Water Bolt',
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
            emissionRate = 5000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.08, size = 2, colors = { 1,1,1,1, 0.5,0.5,0.5,1, 1,1,1,0 }
        })
        local mover = Mover(particle, target, len / speed, 'inCubic')

        mover:setOnComplete(function ()
            particle:remove()

            local particle2 = ParticleEffect(caster.x, caster.y, {
                emissionRate = 3500, distribution = 'ellipse', dx = 7, dy = 7,
                min = 0.15, max = 0.35, size = 2, colors = { 1,1,0,1, 0.5,0.5,0.5,1, 1,1,1,0 }
            })
            particle2.system:setRadialAcceleration(75, 100)
            particle2.system:emit(200)
            particle2:remove()

            spellcast:dealDamage(target)
            
            target:addModifier(Modifier.battleAdd('initiative', -6, {
                id = 'speed_debuff',
                duration = { type = 'turn', value = 3 },
            }))

            spellcast:complete()
        end)

        spellcast:addEffect(mover)
        spellcast:addEffect(particle)
    end
}