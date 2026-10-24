local scale = CHARACTERS_SCALE

return {
    name = 'Frostling',
    sprite_path = 'resources/Characters/Frostling/Frostling.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 24,
    damage = 5,
    attack_range = 1,
    move_range = 3,
    initiative = 8,
    armor = 2,
    max_energy = 9,

    spells = {
        'frost_bite',
        -- 'icy_wind'
    },

    attribute = 'wild',
    element = 'water',

    color = {0, 191, 255} -- Голубой ледяной
}