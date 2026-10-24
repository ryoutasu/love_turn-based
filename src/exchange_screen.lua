local SHARD_TYPES = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }

local SHARD_LABELS = {
    wild = 'Wild', mystic = 'Mystic', mechanic = 'Mechanic',
    ancient = 'Ancient', chaos = 'Chaos',
}

local SHARD_COLORS = {
    wild     = { 0.55, 0.80, 0.30, 1 },
    mystic   = { 0.65, 0.40, 0.90, 1 },
    mechanic = { 0.75, 0.75, 0.85, 1 },
    ancient  = { 0.90, 0.75, 0.35, 1 },
    chaos    = { 0.90, 0.35, 0.35, 1 },
}

local TITLE_FONT = love.graphics.newFont(28)
local LABEL_FONT = love.graphics.newFont(14)
local CHIP_W, CHIP_H = 150, 60
local CHIP_GAP = 12
local RATE = 3

local ExchangeScreen = {
    isOpen    = false,
    player    = nil,
    from_type = 'wild',
    to_type   = 'mystic',
    onClose   = nil,
    message   = "",
    message_color = { 1, 1, 1, 1 },
}

function ExchangeScreen:open(player, onClose)
    self.isOpen    = true
    self.player    = player
    self.from_type = 'wild'
    self.to_type   = 'mystic'
    self.onClose   = onClose
    self.message   = ""
end

function ExchangeScreen:close()
    self.isOpen  = false
    self.player  = nil
    local cb = self.onClose
    self.onClose = nil
    if cb then cb() end
end

function ExchangeScreen:isActive()
    return self.isOpen
end

-- Внутренний: рисуем ряд чипов, возвращаем выбранный
function ExchangeScreen:_drawChipRow(prefix, selected_type, on_select)
    local n = #SHARD_TYPES
    local total_w = n * CHIP_W + (n - 1) * CHIP_GAP
    
    UI.backdrop(prefix .. "backdrop", 0, 0, total_w, CHIP_H, "TOP", { 0, 0, 0, 0 })
    UI.nextPosition("LEFT")
    for i, shard_type in ipairs(SHARD_TYPES) do
        local color  = SHARD_COLORS[shard_type]
        local is_sel = (shard_type == selected_type)
        local count  = self.player:getShard(shard_type)

        UI.setStyle({
            draw_border      = true,
            border_color     = is_sel and { 1, 1, 1, 1 } or { 0.2, 0.2, 0.2, 1 },
            border_width     = is_sel and 3 or 1,
            background_color = color,
            corner_radius    = 8,
        })
        if UI.button(prefix .. shard_type, 0, 0, CHIP_W, CHIP_H, "", "LEFT") then
            on_select(shard_type)
        end

        UI.setStyle({})
        UI.nextPosition("TOP", prefix .. shard_type)
        UI.text(0, 6, SHARD_LABELS[shard_type], "TOP", { 1, 1, 1, 1 }, LABEL_FONT)
        UI.nextPosition("BOTTOM", prefix .. shard_type)
        UI.text(0, -4, tostring(count), "BOTTOM", { 1, 1, 1, 1 }, TITLE_FONT)

        UI.nextPosition("RIGHT", prefix .. shard_type, CHIP_GAP)
    end
end

function ExchangeScreen:draw()
    if not self.isOpen then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Затемняющий фон
    UI.setStyle({
        draw_border      = false,
        background_color = { 0.06, 0.06, 0.09, 0.92 },
        corner_radius    = 0,
    })
    UI.nextPosition("CENTER", "root")
    UI.backdrop("exch_blocker", 0, 0, sw, sh, "CENTER")

    UI.setStyle({})
    UI.nextPosition("TOP", "root")
    UI.text(0, 50, "Exchange Shards", "TOP", { 1, 1, 1, 1 }, TITLE_FONT)

    UI.nextPosition("BOTTOM")
    UI.text(0, 10,
        "Trade " .. RATE .. " shards of one type for 1 of another.",
        "TOP", { 0.7, 0.7, 0.7, 1 }, LABEL_FONT)

    -- FROM
    UI.nextPosition("BOTTOM")
    UI.text(0, 30, "From", "TOP", { 1, 0.85, 0.4, 1 }, LABEL_FONT)
    UI.nextPosition("BOTTOM", _, 0, 30)
    self:_drawChipRow("exch_from_", self.from_type,
        function(t) self.from_type = t end)

    -- TO
    UI.nextPosition("BOTTOM", "exch_from_backdrop")
    UI.text(0, 30, "To", "TOP", { 0.6, 0.9, 1, 1 }, LABEL_FONT)
    UI.nextPosition("BOTTOM", _, 0, 30)
    self:_drawChipRow("exch_to_", self.to_type,
        function(t) self.to_type = t end)

    -- Состояние и кнопка Exchange
    local same_type      = self.from_type == self.to_type
    local have_enough    = self.player:hasShards(self.from_type, RATE)
    local can_exchange   = (not same_type) and have_enough

    UI.nextPosition("BOTTOM", "exch_to_backdrop")
    UI.text(0, 50, "Trade " .. RATE .. " " .. SHARD_LABELS[self.from_type]
        .. " -> 1 " .. SHARD_LABELS[self.to_type],
        "TOP", { 0.9, 0.9, 0.9, 1 }, LABEL_FONT)

    if self.message ~= "" then
        UI.nextPosition("BOTTOM")
        UI.text(0, 50, self.message, "TOP", self.message_color, LABEL_FONT)
    end

    -- Close
    UI.nextPosition("BOTTOM", "root")
    if UI.button("exch_close", 0, -40, 180, 44, "Close", "BOTTOM") then
        self:close()
    end

    -- Кнопка Exchange
    UI.nextPosition("TOP")
    if UI.button("exch_do", 0, -50, 220, 52, "Exchange", "BOTTOM", can_exchange) then
        if same_type then
            self.message = "Choose different types."
            self.message_color = { 1, 0.4, 0.4, 1 }
        elseif not have_enough then
            self.message = "Not enough shards."
            self.message_color = { 1, 0.4, 0.4, 1 }
        else
            if self.player:exchangeShards(self.from_type, self.to_type, RATE) then
                self.message = "Done!"
                self.message_color = { 0.4, 1, 0.4, 1 }
                PlaySound(ButtonClickSound)
            end
        end
    end
end

return ExchangeScreen