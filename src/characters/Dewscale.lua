local scale = CHARACTERS_SCALE

return {
    name = 'Dewscale',
    sprite_path = 'resources/Characters/Dewscale/Dewscale_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 50,
    damage = 10,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    max_energy = 20,
    spells = {
        'claws'
    },
    element = 'water'
}