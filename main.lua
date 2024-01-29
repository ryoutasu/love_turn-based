require 'colors'
Class = require 'lib.class'
Gamestate = require 'lib.gamestate'
Vector = require 'lib.vector'
Urutora = require 'lib.urutora'
Tagtext = require 'src.tagtext'()
Particles = require 'src.particles'()
-- Input = require 'lib.input'

BattleState = require 'src.states.battlestate'

function love.load()
    love.window.setMode(1280, 720)
    -- Input.bind_callbacks()
    love.graphics.setDefaultFilter( 'nearest', 'nearest' )
    love.window.setTitle('Love Turn-Based')
    math.randomseed(os.time())

    -- love.graphics.setBackgroundColor(0.2, 0.35, 0.6, 1)
    love.graphics.setBackgroundColor(0.65, 0.65, 0.65, 1)
    love.graphics.setColor(0, 0, 0, 1)

    Gamestate.registerEvents()
    Gamestate.switch(BattleState)
end

function love.update(dt)
    Particles:update(dt)
    Tagtext:update(dt)
end

function love.draw()
    BattleState:draw()
    Tagtext:draw()
    Particles:draw()
end

function love.mousepressed(...)
    
end