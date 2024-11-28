local scale = 0.6

return {
    name = 'Terrow',
    sprite_path = 'resources/Characters/Terrow/Terrow_Low_indexed.png',
    rect = { 128 * scale, 128 * scale, 128 * scale, 128 * scale },
    scale = scale,

    health = 100,
    damage = 10,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    spells = {
        'slash',
    },
}