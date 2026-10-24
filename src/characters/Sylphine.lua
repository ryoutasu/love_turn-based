local scale = CHARACTERS_SCALE

return {
    name = 'Sylphine',
    sprite_path = 'resources/Characters/Sylphine/Sylphine.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 18,
    damage = 4,
    attack_range = 2,
    move_range = 6,
    initiative = 16,
    armor = 0,
    max_energy = 12,

    spells = {
        'gust',
        'vortex'
    },
    
    attribute = 'mystic',
    element = 'plant',

    color = {173, 216, 230} -- Светло-голубой
}
