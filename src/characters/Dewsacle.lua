local scale = 0.6

return {
    name = 'Dewscale',
    sprite_path = 'Dewscale_Low_Mirrored',
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