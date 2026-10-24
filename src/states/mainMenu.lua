local SaveManager = require 'src.save_manager'
local Player      = require 'src.player'
local RunState    = require 'src.states.run_state'

local titleFont = love.graphics.newFont(34)
local smallFont = love.graphics.newFont(20)

local MainMenu = {}

local titleX, titleY = 55, 55
local startGameButtonW, startGameButtonH = 150, 60

function MainMenu:init() end

function MainMenu:enter()
    IntroMusic:play()
end

function MainMenu:leave() end
function MainMenu:update(dt) end

function MainMenu:draw()
    UI.nextPosition("TOPLEFT")
    UI.text(titleX + 2, titleY + 2, "DumbBeasts adventures", "TOPLEFT", { 0.3, 0.3, 0.3, 1 }, titleFont)
    UI.text(titleX, titleY, "DumbBeasts adventures", "TOPLEFT", { 1, 1, 1, 1 }, titleFont)

    UI.nextPosition("BOTTOMLEFT")
    UI.text(4, 7, "or something like that", "TOPLEFT", { 0.3, 0.3, 0.3, 1 }, smallFont)
    UI.text(2, 5, "or something like that", "TOPLEFT", { 1, 1, 1, 1 }, smallFont)

    UI.nextPosition("BOTTOMLEFT")
    if UI.button("start_game", 0, 50, startGameButtonW, startGameButtonH,
        "Start game", "TOPLEFT") then
        PlaySound(ButtonClickSound)
        Gamestate.switch(CharacterSelect)
    end

    -- Load — только если есть сохранение
    if SaveManager.exists() then
        UI.nextPosition("BOTTOMLEFT")
        if UI.button("load_game", 0, 20, startGameButtonW, startGameButtonH,
            "Continue", "TOPLEFT") then
            PlaySound(ButtonClickSound)
            self:_loadGame()
        end
        UI.nextPosition("BOTTOMLEFT")
        if UI.button("town_delete_save", 0, 20, startGameButtonW, startGameButtonH,
            "Delete save", "TOPLEFT") then
            SaveManager.delete()
            PlaySound(ButtonClickSound)
        end
    end
end

function MainMenu:_loadGame()
    local data = SaveManager.load()
    if not data then
        PlaySound(ErrorSound)
        return
    end

    local player = Player()
    player:deserialize(data.player)

    RunState:deserialize(data.run)

    if data.screen == 'levelmap' and data.levelmap then
        Gamestate.switch(Levelmap, {
            player         = player,
            load_from_save = true,
            save_data      = data.levelmap,
        })
    else
        Gamestate.switch(TownState, { player = player })
    end
end

return MainMenu