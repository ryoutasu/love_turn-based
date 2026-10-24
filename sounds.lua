-- ButtonClickSound = love.audio.newSource('resources/buttonClick.wav', 'static')
-- CheckBoxSound = love.audio.newSource('resources/buttonClick.wav', 'static')

ButtonClickSound = love.audio.newSource('resources/Sounds/buttonClick.wav', 'static')
CheckBoxSound = love.audio.newSource('resources/Sounds/click.wav', 'static')
ErrorSound = love.audio.newSource('resources/Sounds/error.wav', 'static')
CoinsSound = love.audio.newSource('resources/Sounds/coinsSound.wav', 'static')
BoopSound = love.audio.newSource('resources/Sounds/click_005.ogg', 'static')
StepSound = love.audio.newSource('resources/Sounds/click_001.ogg', 'static')

IntroMusic = love.audio.newSource('resources/Sounds/intro.mp3', 'static')
FieldMusic = love.audio.newSource('resources/Sounds/field_music.wav', 'static')
BattleMusic = love.audio.newSource('resources/Sounds/battle_music.mp3', 'static')
VictoryMusic = love.audio.newSource('resources/Sounds/victory.mp3', 'static')

IntroMusic:setVolume(0.8)
FieldMusic:setVolume(0.3)
BattleMusic:setVolume(0.3)
VictoryMusic:setVolume(0.3)

IntroMusic:setLooping(true)
FieldMusic:setLooping(true)
BattleMusic:setLooping(true)

love.audio.setEffect("myEffect", { type="chorus" })

function PlaySound(sound, volume, effect)
    -- if not SOUND_ON then return end
    local source = sound:clone()
    source:setVolume(volume or 1)
    -- if effect then source:setEffect(effect) end
    love.audio.play(source)
    return source
end