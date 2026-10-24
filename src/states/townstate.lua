local Player = require 'src.player'

local SaveManager = require 'src.save_manager'
local RunState    = require 'src.states.run_state'

local ExchangeScreen = require 'src.exchange_screen'
local CraftScreen    = require 'src.craft_screen'

local font = love.graphics.newFont(40)

local TownState = {}

function TownState:init()
    self.active = true
end

function TownState:enter(state, args)
    local seed = args.seed or os.time()
    math.randomseed(seed)
    self.seed = seed

    if args.player then
        self.player = args.player
    else
        self.player = Player()
        for _, value in ipairs(args.characters or {}) do
            self.player:addCharacter(value)
        end
        self.player:addItem('healPotion', 2)
        self.player:addItem('energyPotion', 2)
        self.player:addCurrency('gold', 100)
    end
    
    local ok = SaveManager.save(self.player, RunState, nil, 'town')
end

function TownState:resume()
    self.active = true
end

function TownState:leave()
    self.active = false
end

function TownState:update(dt)
end

-- local font = love.graphics.newFont(24)
function TownState:draw()
    if self.active then
        -- UI.setFont(font)
        UI.nextPosition("TOP")
        UI.text(6, 63, "Welcome to the Dumbville town!", "TOP", { 0, 0, 0, 1 }, font)
        UI.text(3, 60, "Welcome to the Dumbville town!", "TOP", { 1, 1, 1, 1 }, font)

        UI.nextPosition("BOTTOM", "root")
        if UI.button("town_begin", 0, -100, 200, 100, "Begin", "BOTTOM") then
            PlaySound(ButtonClickSound)
            Shop.refreshed = false
            Gamestate.push(Levelmap, { player = self.player, seed = self.seed })
            self.active = false
        end
        
        UI.nextPosition("CENTER", "root")
        if UI.button("town_stables", -50, -50, 200, 100, "Stables", "BOTTOMRIGHT") then
            PlaySound(ButtonClickSound)
            Gamestate.push(Stables, { player = self.player })
            self.active = false
        end
        
        if UI.button("town_shop", 50, -50, 200, 100, "Shop", "BOTTOMLEFT") then
            PlaySound(ButtonClickSound)
            Gamestate.push(Shop, { player = self.player, seed = self.seed })
            self.active = false
        end

        -- Exchange
        UI.nextPosition("CENTER", "root")
        if UI.button("town_exchange", -320, 0, 200, 60, "Exchange", "CENTER") then
            ExchangeScreen:open(self.player)
            PlaySound(ButtonClickSound)
        end

        -- Craft
        UI.nextPosition("CENTER", "root")
        if UI.button("town_craft", 320, 0, 200, 60, "Craft", "CENTER") then
            CraftScreen:open(self.player)
            PlaySound(ButtonClickSound)
        end
    end

    ExchangeScreen:draw()
    CraftScreen:draw()
end

return TownState