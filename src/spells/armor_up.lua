local VisualEffect = require 'src.spellcast.visualEffect'
local SimpleSwoosh = require 'src.spellcast.effects.simpleSwoosh'

return {
    name = 'Armor Up',
    type = 'unit',
    range = 0,
    filter = TargetFactory.ally,
    element = 'earth',
    cost = 2,
    cooldown = 2,
    onCast = function (spellcast, caster, target)
        -- target:add_bonus_stat('armor', 2)
        -- target:add_status_effect({
        --     name = 'Armor Up',
        --     duration = 5,
        --     target = target,
        --     caster = caster,
        --     on_tick = function() end,
        --     on_expire = function(self) self.target:add_bonus_stat('armor', -2) end
        -- })
        target:addModifier(Modifier.battleAdd('armor', 2, {
            id = 'armor_buff',
            duration = { type = 'turn', value = 2 },
        }))

        spellcast:complete()
    end
}