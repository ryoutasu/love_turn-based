local scale = CHARACTERS_SCALE

return {
    name = 'Terrow',
    sprite_path = 'resources/Characters/Terrow/Terrow_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 120,
    damage = 8,
    attack_range = 1,
    move_range = 3,
    initiative = 6,
    armor = 2,
    max_energy = 20,

    spells = {
        'claws'
    },
    element = 'stone'
}