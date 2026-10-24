local scale = CHARACTERS_SCALE

return {
    name = 'Brambleclaw',
    sprite_path = 'resources/Characters/Brambleclaw/Brambleclaw.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 40,
    damage = 7,
    attack_range = 1,
    move_range = 3,
    initiative = 6,
    armor = 1,
    max_energy = 8,

    spells = {
        'thorn_strike',
        'entangle'
    },

    attribute = 'mystic',
    element = 'plant',

    color = {34, 139, 34} -- Лесной зелёный
}