local scale = CHARACTERS_SCALE

return {
    name = 'Quillpaw',
    sprite_path = 'resources/Characters/Quillpaw/Quillpaw_Low_Mirrored.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 24,
    damage = 6,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    armor = 1,
    max_energy = 8,

    spells = {
        'claws'
    },
    
    attribute = 'wild',
    element = 'earth',

    starter_character = true
}