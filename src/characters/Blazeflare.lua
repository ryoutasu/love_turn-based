local scale = CHARACTERS_SCALE

return {
    name = 'Blazeflare',
    sprite_path = 'resources/Characters/Blazeflare/Blazeflare.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 30,
    damage = 6,
    attack_range = 1,
    move_range = 4,
    initiative = 10,
    armor = 1,
    max_energy = 10,

    spells = {
        'explosive_burst'
    },
    
    attribute = 'mystic',
    element = 'ember',
    
    color = {255, 69, 0} -- Ярко-оранжевый
}