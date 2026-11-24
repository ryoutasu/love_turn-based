-- src/states/exhaustionstate.lua
--
-- End-of-run screen for the fatigue rule: every creature that could enter a
-- battle has reached Fatigue.MAX, so the run cannot continue. This is not a
-- combat defeat — no lives were spent — so the screen always exits to Town,
-- which is where fatigue is relieved.
--
-- Pushed by Levelmap:_handle_party_exhausted via Gamestate.switch, so Levelmap
-- is no longer below us on the stack.

local Fatigue = require 'src.fatigue'

local titleFont = love.graphics.newFont(44)
local nameFont  = love.graphics.newFont(16)
local smallFont = love.graphics.newFont(12)

local CARD_W, CARD_H = 150, 150
local CARD_GAP       = 20

local ExhaustionState = {}

function ExhaustionState:init()
    self.player = nil
    self.ready  = false
end

function ExhaustionState:enter(_, args)
    self.player = args and args.player or nil
    self.ready  = false
end

function ExhaustionState:leave() end
function ExhaustionState:update(dt) end
function ExhaustionState:keypressed(key, scancode, isrepeat) end

-- ================================================================
-- Draw
-- ================================================================

function ExhaustionState:_party()
    return Fatigue.party(self.player)
end

function ExhaustionState:draw()
    love.graphics.clear(0.08, 0.07, 0.10, 1)

    UI.setStyle({})
    UI.setFont(titleFont)
    UI.nextPosition("TOP", "root")
    UI.text(3, 33, "Party exhausted", "TOP", { 0, 0, 0, 1 })
    UI.text(0, 30, "Party exhausted", "TOP", { 0.95, 0.8, 0.4, 1 })

    UI.setFont(nameFont)
    UI.nextPosition("TOP", "root")
    UI.text(0, 95, "Everyone is too tired to fight. The expedition ends here.",
        "TOP", { 0.85, 0.85, 0.9, 1 })

    local party = self:_party()
    if #party > 0 then
        self:_drawCards(party)
    end

    UI.setStyle({
        draw_border      = true,
        border_color     = { 0, 0, 0, 1 },
        background_color = { 0.6, 0.6, 0.8, 1 },
    })
    UI.setFont(nameFont)
    UI.nextPosition("BOTTOM", "root")
    if UI.button("exhaustion_return", 0, -60, 320, 80, "Return to Town", "BOTTOM") then
        self:_returnToTown()
    end
end

function ExhaustionState:_drawCards(party)
    local sw    = love.graphics.getWidth()
    local total = #party * CARD_W + (#party - 1) * CARD_GAP
    local x     = (sw - total) / 2
    local y     = 170

    for _, c in ipairs(party) do
        self:_drawCard(c, x, y)
        x = x + CARD_W + CARD_GAP
    end
end

function ExhaustionState:_drawCard(c, x, y)
    love.graphics.setColor(0.20, 0.18, 0.22, 0.95)
    love.graphics.rectangle('fill', x, y, CARD_W, CARD_H, 8, 8)

    love.graphics.setColor(0.75, 0.45, 0.35, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, CARD_W, CARD_H, 8, 8)

    if c.sprite then
        local scale = 0.5
        local sx    = x + CARD_W / 2 - c.sprite.w * scale / 2
        love.graphics.setColor(1, 1, 1, 1)
        c.sprite:draw(c.quad, sx, y + 16, 0, scale, scale)
    end

    love.graphics.setFont(nameFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(c.name or '?', x, y + 100, CARD_W, 'center')

    local value   = Fatigue.get(c)
    local ratio   = value / Fatigue.MAX
    local bar_x   = x + 12
    local bar_w   = CARD_W - 24
    local bar_h   = 12
    local bar_y   = y + 128

    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Fatigue " .. value .. "/" .. Fatigue.MAX,
        x, bar_y - 16, CARD_W, 'center')

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w, bar_h)
    love.graphics.setColor(0.9, 0.55, 0.2, 1)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w * ratio, bar_h)
end

-- ================================================================
-- Flow
-- ================================================================

function ExhaustionState:_returnToTown()
    if self.ready then return end
    self.ready = true

    local player = self.player
    PlaySound(ButtonClickSound)

    Gamestate.push(FadeInState, {
        color = { r = 0, g = 0, b = 0 },
        time  = 1,
        onFadeComplete = function()
            Gamestate.switch(TownState, { player = player })
        end,
    })
end

return ExhaustionState
