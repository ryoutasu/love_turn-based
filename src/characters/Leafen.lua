local scale = CHARACTERS_SCALE

return {
    name = 'Leafen',
    sprite_path = 'resources/Characters/Leafen/Leafen_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 20,
    damage = 5,
    attack_range = 1,
    move_range = 3,
    initiative = 7,
    armor = 1,
    max_energy = 12,

    spells = {
        -- 'spit',
        'leaf_strike'
    },
    
    attribute = 'mystic',
    element = 'plant',
    
    starter_character = true
}