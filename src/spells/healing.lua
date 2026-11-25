local VisualEffect = require 'src.spellcast.visualEffect'
local SimpleSwoosh = require 'src.spellcast.effects.simpleSwoosh'

return {
    name = 'Claws',
    type = 'unit',
    range = 1,
    filter = TargetFactory.ally,
    element = 'neutral',
    cost = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local effect = VisualEffect(SimpleSwoosh(0, 0, 16, 16, 4), { x = target.x, y = target.y } )
        effect:setOnComplete(function ()
            Tagtext:add('+15', target.x + 5, target.y - 40, 2, 30, { 1, 1, 1 })
            target.health = target.health + 15

            spellcast:complete()
        end)
        spellcast:addEffect(effect)
    end
}