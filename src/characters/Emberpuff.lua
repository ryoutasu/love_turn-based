local scale = CHARACTERS_SCALE

return {
    name = 'Emberpuff',
    sprite_path = 'resources/Characters/Emberpuff/Emberpuff_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 28,
    damage = 6,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    armor = 1,
    max_energy = 10,

    spells = {
        'fireball',
        'ignite',
        'earthquake',
    },
    
    attribute = 'wild',
    element = 'ember',
    
    starter_character = true
}