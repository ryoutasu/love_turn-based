local scale = CHARACTERS_SCALE

return {
    name = 'Voltling',
    sprite_path = 'resources/Characters/Voltling/Voltling_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 20,
    damage = 5,
    attack_range = 2,
    move_range = 5,
    initiative = 12,
    armor = 0,
    max_energy = 10,

    spells = {
        -- 'thunder_jolt',
        -- 'charge'
    },
    
    attribute = 'mystic',
    element = 'storm',

    color = {255, 215, 0}, -- Ярко-желтый, цвет электричества
    starter_character = true
}
