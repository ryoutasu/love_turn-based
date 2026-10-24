local scale = CHARACTERS_SCALE

return {
    name = 'Aetheris',
    sprite_path = 'resources/Characters/Aetheris/Aetheris.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 20,
    damage = 4,
    attack_range = 2,
    move_range = 5,
    initiative = 14,
    armor = 0,
    max_energy = 20,

    spells = {
        'speed_up',
        -- 'celestial_burst',
        -- 'radiant_shield'
    },

    attribute = 'mystic',
    element = 'light',

    color = {255, 255, 224} -- Светло-желтый
}
