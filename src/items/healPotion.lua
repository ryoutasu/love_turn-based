return {
    id          = 'healPotion',
    name        = 'Healing Potion',
    description = 'Restore 20 HP to one creature.',
    color       = { 0.25, 1, 0.45, 1 },
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
        type   = 'restore_hp',
        amount = 20,
    },
}