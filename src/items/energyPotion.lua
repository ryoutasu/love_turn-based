return {
    id          = 'energyPotion',
    name        = 'Energy Potion',
    description = 'Restore 10 energy to one creature.',
    color       = { 0.25, 0.35, 1, 1 },
    cost        = 20,

    usableOnMap   = true,
    usableInFight = true,
    targetType    = 'ally',
    range         = 100,
    filter = function(target)
        return target.actor and target.actor.is_player
            or (target.character and target.is_player)
    end,

    effect = {
        type   = 'restore_energy',
        amount = 10,
    },
}