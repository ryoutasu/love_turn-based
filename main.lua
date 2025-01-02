if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

love.window.setMode(1280, 720)

DEBUG = false
CHARACTERS_SCALE = 0.6

require 'utils'
require 'sounds'

Ripple = require 'lib.ripple'
Class = require 'lib.class'
Gamestate = require 'lib.gamestate'
Vector = require 'lib.vector'
Urutora = require 'lib.urutora'
Tagtext = require 'src.tagtext'()
Particles = require 'src.particles'()
-- Input = require 'lib.input'
require 'colors'

MainMenuState = require 'src.states.mainMenu'
CharacterSelect = require 'src.states.characterSelect'
-- Level states (BattleState, EventState, etc.) before Levelmap state !!!
BattleState = require 'src.states.battlestate'
RestState = require 'src.states.reststate'
EventState = require 'src.states.eventstate'
Levelmap = require 'src.states.levelmap2'

function love.load()
    -- Input.bind_callbacks()
    -- love.graphics.setDefaultFilter( 'nearest', 'nearest' )
    love.window.setTitle('Love Turn-Based')

    love.graphics.setBackgroundColor(0.65, 0.65, 0.65, 1)

    Gamestate.registerEvents()
    Gamestate.switch(MainMenuState)
end

function love.update(dt)
    Particles:update(dt)
    Tagtext:update(dt)
end

function love.draw()
    Gamestate.current():draw()
    Tagtext:draw()
    Particles:draw()
end

function love.keypressed(key)
    if key == 'f1' then
        DEBUG = not DEBUG
    end
end