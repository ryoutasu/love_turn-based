COLOR_ID = {
    TRANSPARENT_GREY = 1,
    DARK_GREY = 2,
    GREEN = 3,
    LIGHT_GREEN = 4,
    YELLOW = 5,
    BLUE = 6,
    RED = 7,
    BRIGHT_RED = 8,
    BRIGHT_YELLOW = 9,
    ORANGE = 10,
    LIGHT_BLUE = 11,
    SOME = 12,

    SHADE_GREEN = 13,
    SHADE_LIGHT_BLUE = 14,
    SHADE_DARK_GREEN = 15,
}

TILE_COLOR = {
    [COLOR_ID.TRANSPARENT_GREY] = { 0.35, 0.35, 0.35, 0.3 },
    [COLOR_ID.DARK_GREY] = { 0.35, 0.35, 0.35, 0.5 },
    [COLOR_ID.GREEN] = { 79/255, 121/255, 66/255, 0.75 },
    [COLOR_ID.LIGHT_GREEN] = { 75/255, 160/255, 125/255, 0.3 },
    [COLOR_ID.YELLOW] = { 153/255, 153/255, 80/255, 0.6 },
    [COLOR_ID.BLUE] = { 65/255, 65/255, 153/255, 0.6 },
    [COLOR_ID.RED] = { 153/255, 65/255, 65/255, 0.6 },
    [COLOR_ID.BRIGHT_RED] = { 150/255, 35/255, 35/255, 0.3 },
    [COLOR_ID.BRIGHT_YELLOW] = Urutora.utils.brighter({ 153/255, 153/255, 80/255, 0.6 }),
    [COLOR_ID.ORANGE] = { 152/255, 94/255, 52/255, 0.5 },
    [COLOR_ID.LIGHT_BLUE] = { 75/255, 125/255, 160/255, 0.3 },
    [COLOR_ID.SOME] = { 75/255, 75/255, 155/255, 0.4 },

    [COLOR_ID.SHADE_GREEN] = { 51/255, 102/255, 0/255, 0.4 },
    [COLOR_ID.SHADE_LIGHT_BLUE] = { 0/255, 102/255, 102/255, 0.4 },
    [COLOR_ID.SHADE_DARK_GREEN] = { 25/255, 51/255, 0/255, 0.4 },
}

OUTLINE_COLOR = {
    [COLOR_ID.TRANSPARENT_GREY] = { 0.25, 0.25, 0.25, 0.85 },
    [COLOR_ID.DARK_GREY] = { 0.25, 0.25, 0.25, 0.85 },
    [COLOR_ID.GREEN] = { 35/255, 60/255, 33/255, 1 },
    [COLOR_ID.LIGHT_GREEN] = { 29/255, 55/255, 25/255, 1 },
    [COLOR_ID.YELLOW] = { 85/255, 85/255, 45/255, 1 },
    [COLOR_ID.BLUE] = { 35/255, 35/255, 85/255, 1 },
    [COLOR_ID.RED] = { 85/255, 35/255, 35/255, 1 },
    [COLOR_ID.BRIGHT_RED] = { 100/255, 35/255, 35/255, 1 },
    [COLOR_ID.BRIGHT_YELLOW] = { 85/255, 85/255, 45/255, 1 },
}