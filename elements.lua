ATTRIBUTES = {
    wild = "Wild",
    mystic = "Mystic",
    mechanic = "Mechanic",
    ancient = "Ancient",
    -- Ключ должен совпадать с игровым ('chaos'): везде в коде —
    -- SHARD_TYPES, data/type_chart.lua, character_pool — используется 'chaos'.
    -- Раньше здесь стояло 'chaotic', и метка Chaos никогда не находилась
    -- (в UI показывался сырой ключ или nil).
    chaos = "Chaos"
}

ELEMENTS = {
    ember = "Ember",
    water = "Water",
    earth = "Earth",
    storm = "Storm",
    light = "Light",
    dark = "Dark",
    plant = "Plant",
    -- «Нейтральный» урон: используется заклинаниями claws/sand_throw/healing.
    -- Без этой строки UI показывал бы сырой ключ 'neutral'.
    neutral = "Neutral"
}