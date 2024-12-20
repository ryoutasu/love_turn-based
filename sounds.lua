-- ButtonClickSound = love.audio.newSource('resources/buttonClick.wav', 'static')
-- CheckBoxSound = love.audio.newSource('resources/buttonClick.wav', 'static')

ButtonClickSound = 'resources/Sounds/buttonClick.wav'
CheckBoxSound = 'resources/Sounds/buttonClick.wav'
ErrorSound = 'resources/Sounds/nope.wav'

love.audio.setEffect("myEffect", { type="chorus" })

function PlaySound(sound, volume, effect)
    local source = love.audio.newSource(sound, 'static')
    source:setVolume(volume or 1)
    if effect then source:setEffect(effect) end
    love.audio.play(source)
end