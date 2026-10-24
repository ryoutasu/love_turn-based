local scale = CHARACTERS_SCALE

return {
    name = 'Mystwing',
    sprite_path = 'resources/Characters/Mystwing/Mystwing.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 20,
    damage = 5,
    attack_range = 2,
    move_range = 5,
    initiative = 12,
    armor = 1,
    max_energy = 12,

    spells = {
        'gust',
        'vortex'
    },
    
    attribute = 'wild',
    element = 'storm',
    
    color = {135, 206, 235} -- Небесно-голубой
}