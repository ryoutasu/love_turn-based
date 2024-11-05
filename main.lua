require 'utils'

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
Levelmap = require 'src.states.levelmap2'
BattleState = require 'src.states.battlestate'

function love.load()
    love.window.setMode(1280, 720)
    -- Input.bind_callbacks()
    love.graphics.setDefaultFilter( 'nearest', 'nearest' )
    love.window.setTitle('Love Turn-Based')
    math.randomseed(os.time())

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