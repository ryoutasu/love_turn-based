local scale = CHARACTERS_SCALE

return {
    name = 'Marilix',
    sprite_path = 'resources/Characters/Marilix/Marilix.png',
    rect = { 140 * scale, 140 * scale, 140 * scale, 140 * scale },
    scale = scale,

    max_health = 28,
    damage = 6,
    attack_range = 1,
    move_range = 3,
    initiative = 8,
    armor = 1,
    max_energy = 7,

    spells = {
        'coral_strike',
        'tidal_shield'
    },
    
    attribute = 'mystic',
    element = 'water',
    
    color = {64, 164, 223} -- Светло-голубой, отражающий водную стихию
}