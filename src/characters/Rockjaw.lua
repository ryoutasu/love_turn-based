local scale = CHARACTERS_SCALE

return {
    name = 'Rockjaw',
    sprite_path = 'resources/Characters/Rockjaw/Rockjaw.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 42,
    damage = 7,
    attack_range = 1,
    move_range = 3,
    initiative = 5,
    armor = 2,
    max_energy = 5,

    spells = {
        'stone_crush'
    },
    
    attribute = 'mystic',
    element = 'earth',

    color = {105, 105, 105} -- Темно-серый
}
