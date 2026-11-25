return {
    name = 'Speed Up',
    type = 'unit',
    range = 5,
    filter = TargetFactory.ally,
    element = 'storm',
    cost = 2,
    cooldown = 2,
    onCast = function (spellcast, caster, target)
        -- target:add_bonus_stat('initiative', 4)
        -- target:add_status_effect({
        --     name = 'Speed Up',
        --     duration = 5,
        --     target = target,
        --     caster = caster,
        --     on_tick = function() end,
        --     on_expire = function(self) self.target:add_bonus_stat('initiative', -4) end
        -- })

        target:addModifier(Modifier.battleAdd('initiative', 3, {
            id = 'speed_buff',
            duration = { type = 'turn', value = 3 },
        }))

        spellcast:complete()
    end
}