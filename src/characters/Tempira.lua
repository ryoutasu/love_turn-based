local scale = CHARACTERS_SCALE

return {
    name = 'Tempira',
    sprite_path = 'resources/Characters/Tempira/Tempira_Low_indexed.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 22,
    damage = 5,
    attack_range = 2,
    move_range = 5,
    initiative = 13,
    armor = 1,
    max_energy = 15,

    spells = {
        'water_spout',
        'storm_dash'
    },
    
    attribute = 'mystic',
    element = 'water',

    color = {64, 224, 208} -- Бирюзовый оттенок
}
