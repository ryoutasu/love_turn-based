local scale = CHARACTERS_SCALE

return {
    name = 'Quillpaw',
    sprite_path = 'resources/Characters/Quillpaw/Quillpaw_Low_Mirrored.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 50,
    damage = 10,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    spells = {
        'claws'
    },
    element = 'normal'
}