local scale = CHARACTERS_SCALE

return {
    name = 'Terrow',
    sprite_path = 'resources/Characters/Terrow/Terrow_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 100,
    damage = 10,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    armor = 2,

    spells = {
        'claws'
    },
    element = 'stone'
}