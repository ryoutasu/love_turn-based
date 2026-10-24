local scale = CHARACTERS_SCALE

return {
    name = 'Flarevine',
    sprite_path = 'resources/Characters/Flarevine/Flarevine.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 24,
    damage = 6,
    attack_range = 1,
    move_range = 4,
    initiative = 11,
    armor = 1,
    max_energy = 14,

    spells = {
        'burn_leaf'
    },
    
    attribute = 'mystic',
    element = 'plant',
    
    color = {255, 69, 0} -- Ярко-оранжевый оттенок
}
