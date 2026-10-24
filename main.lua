if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

love.window.setMode(1280, 720)

DEBUG = false
SOUND_ON = false
CHARACTERS_SCALE = 0.75

require 'utils'
require 'sounds'

require 'src.spellcast.targetFactory'

Ripple = require 'lib.ripple'
Class = require 'lib.class'
Gamestate = require 'lib.gamestate'
Vector = require 'lib.vector'
UI = require 'ui'
Tagtext = require 'src.tagtext'()
Particles = require 'src.particles'()
Modifier = require 'src.modifiers'
local HUD = require 'src.hud'
-- Input = require 'lib.input'
require 'elements'
require 'colors'

MainMenuState = require 'src.states.mainMenu'
CharacterSelect = require 'src.states.characterSelect'
FadeInState = require 'src.states.FadeInState'
FadeOutState = require 'src.states.FadeOutState'
-- town states
Stables = require 'src.states.stables'
Petshop = require 'src.states.petshop'
Shop = require 'src.states.shop'
TownState = require 'src.states.townstate'
-- node states
BattleState = require 'src.states.battlestate'
RestState = require 'src.states.reststate'
ShopState = require 'src.states.shopstate'
EventState = require 'src.states.eventstate'
-- Level states (BattleState, EventState, etc.) before Levelmap state !!!
Levelmap = require 'src.states.levelmap2'


function love.load()
    love.audio.setVolume(SOUND_ON and 1 or 0)
    -- Input.bind_callbacks()
    -- love.graphics.setDefaultFilter( 'nearest', 'nearest' )
    love.window.setTitle('Love Turn-Based')

    love.graphics.setBackgroundColor(0.65, 0.65, 0.65, 1)

    Gamestate.registerEvents()
    Gamestate.switch(MainMenuState--[[ , { player = Player() } ]])
    
    -- local player = Player()
    -- player:addCharacter('Emberpuff', true)
    -- player:addCharacter('Leafen', true)
    -- player:addCharacter('Dewscale', true)
    -- player:addItem('catcher', 2)
    -- Gamestate.switch(BattleState, { player = player, node = { event = Events["abandonedCamp"] } })
end

local lurker = require("lib.lurker")
function love.update(dt)
    lurker.update()
    UI.update(dt)

    Particles:update(dt)
    Tagtext:update(dt)
end

local font = love.graphics.newFont(16)
function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    -- Gamestate.current():draw()

    for index, value in ipairs(Gamestate.stack) do
        value:draw()
    end

    Tagtext:draw()
    Particles:draw()

    if not SOUND_ON then
        UI.nextPosition("BOTTOMRIGHT", "root")
        UI.text(-5, -5, "SOUND OFF", "BOTTOMRIGHT", { 0.5, 0.15, 0.15, 1 }, font)
    end

    HUD:draw()

    UI.draw()
end

function love.keypressed(key, scancode, isrepeat)
    if key == 'f1' then
        DEBUG = not DEBUG
    end

    if key == 'f2' then
        SOUND_ON = not SOUND_ON
        print('Sound turned ' .. (SOUND_ON and 'on' or 'off'))
        love.audio.setVolume(SOUND_ON and 1 or 0)
    end

    if key == "f5" then
        love.event.quit("restart")
    end

    UI.handleKeyPress(key)
end

function love.textinput(text)
    UI.handleTextInput(text)
end