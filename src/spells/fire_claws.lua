local VisualEffect = require 'src.spellcast.visualEffect'
local SimpleSwoosh = require 'src.spellcast.effects.simpleSwoosh'

return {
    name = 'Fire Claws',
    type = 'unit',
    range = 1,
    filter = TargetFactory.enemy,
    element = 'ember',
    cost = 2,
    damage = 15,
    onCast = function (spellcast, caster, target)
        local x = caster.x + (target.x - caster.x)/2
        local y = caster.y + (target.y - caster.y)/2
        local dx, dy = target.x - caster.x, target.y - caster.y
        local effect = VisualEffect(SimpleSwoosh(), { x = x, y = y, r = math.atan2(dy, dx), sx = 1, sy = 2, color = { 1, 0, 0, 1 } } )
        effect:setOnComplete(function ()
            spellcast:dealDamage(target)
            spellcast:complete()
        end)
        spellcast:addEffect(effect)
    end
}