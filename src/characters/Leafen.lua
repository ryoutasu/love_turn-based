local scale = 0.6

return {
    name = 'Leafen',
    sprite_path = 'Leafen_Low5',
    rect = { 96 * scale, 128 * scale, 96 * scale, 128 * scale },
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