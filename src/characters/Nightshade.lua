local scale = CHARACTERS_SCALE

return {
    name = 'Nightshade',
    sprite_path = 'resources/Characters/Nightshade/Nightshade.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 25,
    damage = 6,
    attack_range = 1,
    move_range = 4,
    initiative = 9,
    armor = 2,
    max_energy = 8,

    spells = {
        'toxic_bite',
        'shadow_pulse'
    },
    
    attribute = 'wild',
    element = 'dark',

    color = {75, 0, 130} -- Индиго
}
