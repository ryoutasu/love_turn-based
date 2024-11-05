local titleFont = love.graphics.newFont(30)

local MainMenu = Class{}

local titleX, titleY = 50, 50
local titleW, titleH = 400, 50

local smallTitleX = titleX + 2
local smallTitleY = titleY + titleH - 10
local smallTitleW, smallTitleH = 200, 20

local startGameButtonX = titleX + 10
local startGameButtonY = titleY + titleH + smallTitleH + 50
local startGameButtonW, startGameButtonH = 100, 40

-- local testButtonX = titleX + 10
-- local testButtonY = titleY + titleH + smallTitleH + 50
-- local testButtonW, testButtonH = 100, 40

function MainMenu:init()
    local u = Urutora:new()
    
    local titleLabel = Urutora.label({
        x = titleX, y = titleY,
        w = titleW, h = titleH,
        text = 'Neuromon adventures',
        align = 'left',
    }):setStyle({ font = titleFont, bgColor = { 1, 1, 1, 0 } })

    local smallTitleLabel = Urutora.label({
        x = smallTitleX, y = smallTitleY,
        w = smallTitleW, h = smallTitleH,
        text = 'or something like that',
        align = 'left',
    }):setStyle({ bgColor = { 1, 1, 1, 0 } })

    local startGameButton = Urutora.button({
        x = startGameButtonX, y = startGameButtonY,
        w = startGameButtonW, h = startGameButtonH,
        text = 'Start game',
        align = 'center',
    }):action(function (e)
        -- Gamestate.switch(CharacterSelect)
        Gamestate.push(CharacterSelect)
    end)

    -- local testButton = Urutora.button({
    --     x = testButtonX, y = testButtonY,
    --     w = testButtonW, h = testButtonH,
    --     text = 'Test',
    --     align = 'center',
    -- }):action(function (e)
    --     Gamestate.switch(Roadmap)
    -- end)

    u:add(titleLabel)
    u:add(smallTitleLabel)
    u:add(startGameButton)
    -- u:add(testButton)

    self.u = u
end

function MainMenu:enter()
    
end

function MainMenu:update(dt)
    self.u:update(dt)
end

function MainMenu:draw()
    self.u:draw()
end

function MainMenu:mousepressed(x, y, button) self.u:pressed(x, y, button) end
function MainMenu:mousereleased(x, y, button) self.u:released(x, y) end
function MainMenu:keypressed(key, scancode, isrepeat) self.u:keypressed(key, scancode, isrepeat) end
function MainMenu:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
function MainMenu:textinput(text) self.u:textinput(text) end
function MainMenu:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return MainMenu