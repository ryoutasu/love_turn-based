-- Раньше использовал add_bonus_stat + add_status_effect.
-- Теперь — единый путь через Unit:addModifier с duration.
return {
    id          = 'battleHorn',
    name        = 'Battle Horn',
    description = '+3 damage for 3 turns.',
    color       = { 0.8, 0.6, 0.1, 1 },
    cost        = 40,

    usableOnMap   = false,
    usableInFight = true,
    targetType    = 'ally',
    range         = 100,
    filter = function(target)
        return target.actor and target.actor.is_player
    end,

    effect = {
        type  = 'add_modifier',
        label = 'Bonus damage!',
        modifier = {
            id       = 'battle_horn_buff',
            stat     = 'damage',
            op       = 'add',
            value    = 3,
            duration = { type = 'turn', value = 3 },
            stack    = 'refresh',
        },
    },
}