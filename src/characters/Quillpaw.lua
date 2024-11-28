local scale = 0.6

return {
    name = 'Quillpaw',
    sprite_path = 'resources/Characters/Quillpaw/Quillpaw_Low_Mirrored.png',
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