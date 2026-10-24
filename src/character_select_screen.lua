-- Модальный экран выбора существ после боя.
-- Синглтон по стилю кодовой базы: состояния живут в модуле,
-- Levelmap просто вызывает open/close/draw.
--
-- Поведение (сохранено из старого Levelmap):
--   * клик по существу без выделения — «взять» существо в руку;
--   * клик по существу с выделением — обмен местами;
--   * клик по пустому слоту с выделением — перенести существо туда;
--   * Continue — закрыть экран; неиспользованные существа теряются.

local BUTTON_SIZE   = 80
local OFFSET        = 20
local SPRITE_SCALE  = 0.6

local BUTTON_STYLE = {
    draw_border       = true,
    border_color      = { 0, 0, 0, 1 },
    background_color  = { 0.5, 0.5, 0.5, 0.95 },
}

local BLOCKER_STYLE = {
    draw_border       = false,
    background_color  = { 0.25, 0.25, 0.25, 0.65 },
    corner_radius     = 0,
}

local CharacterSelectScreen = {
    isOpen               = false,
    player               = nil,
    charactersToSelect   = {},
    selectCount          = 0,
    selectedCharacter    = nil,
    selectedCharacterFrom = nil,
    onClose              = nil,
}

-- ------------------------------------------------------------------
-- Жизненный цикл
-- ------------------------------------------------------------------

function CharacterSelectScreen:open(player, list, onClose)
    self.isOpen             = true
    self.player             = player
    self.charactersToSelect = list or {}
    self.selectCount        = #self.charactersToSelect
    self.selectedCharacter  = nil
    self.selectedCharacterFrom = nil
    self.onClose            = onClose
end

function CharacterSelectScreen:close()
    -- Если существо осталось «в руке» — вернуть в исходный слот.
    if self.selectedCharacter and self.selectedCharacterFrom then
        local t = self.selectedCharacterFrom.table
        local i = self.selectedCharacterFrom.index
        t[i] = self.selectedCharacter
    end

    self.isOpen             = false
    self.player             = nil
    self.charactersToSelect = {}
    self.selectCount        = 0
    self.selectedCharacter  = nil
    self.selectedCharacterFrom = nil

    if self.onClose then self.onClose() end
end

function CharacterSelectScreen:isActive()
    return self.isOpen
end

-- ------------------------------------------------------------------
-- Клик по существу
-- ------------------------------------------------------------------

function CharacterSelectScreen:_click(character, from, index)
    if self.selectedCharacter then
        local to      = self.selectedCharacterFrom.table
        local toIndex = self.selectedCharacterFrom.index

        to[toIndex]  = character                    -- в исходный слот — то, что кликнули
        from[index]  = self.selectedCharacter       -- в кликнутый слот — то, что держали

        self.selectedCharacter     = nil
        self.selectedCharacterFrom = nil
    else
        if character then
            self.selectedCharacter     = character
            self.selectedCharacterFrom = { table = from, index = index }
            from[index]                = nil        -- забрали из списка
        end
    end
end

-- ------------------------------------------------------------------
-- Отрисовка
-- ------------------------------------------------------------------

function CharacterSelectScreen:_drawRow(characters, count, prefix,
                                          anchor, x, y)
    UI.setStyle(BUTTON_STYLE)
    -- UI.nextPosition(anchor, "root")

    for i = 1, count do
        local character = characters[i]
        if UI.button(prefix .. i, x, y, BUTTON_SIZE, BUTTON_SIZE, "", anchor) then
            self:_click(character, characters, i)
        end

        if character and character.sprite then
            UI.nextPosition("CENTER")
            UI.image(0, 0, character.sprite.image, "CENTER", SPRITE_SCALE)
        end

        UI.nextPosition("BOTTOMRIGHT", prefix .. i)
        x = OFFSET
        y = 0
    end

    return x, y
end

function CharacterSelectScreen:draw()
    if not self.isOpen then return end

    local player = self.player
    if not player then return end

    -- 1. Затемняющий фон
    UI.setStyle(BLOCKER_STYLE)
    UI.nextPosition("CENTER", "root")
    UI.backdrop("css_blocker", 0, 0,
        love.graphics.getWidth(), love.graphics.getHeight(), "CENTER")

    -- Ширины для центрирования рядов
    local widthActive = player.charactersActiveSize * BUTTON_SIZE
        + player.charactersActiveSize * OFFSET
    local widthSpare  = player.charactersSpareSize * BUTTON_SIZE
        + player.charactersSpareSize * OFFSET
    local widthSelect = self.selectCount * BUTTON_SIZE
        + math.max(self.selectCount - 1, 0) * OFFSET

    -- 2. Ряд активных
    local x = -(widthActive + widthSpare) / 2
    local y = -15
    self:_drawRow(player.charactersActive, player.charactersActiveSize,
        "css_active_", "BOTTOMLEFT", x, y)

    -- Разделитель между активными и запасными
    UI.setStyle({ draw_border = false })
    UI.backdrop("css_divider", OFFSET, 0, 2, BUTTON_SIZE, "BOTTOMLEFT", { 0, 0, 0, 1 })
    UI.nextPosition("BOTTOMRIGHT")

    -- 3. Ряд запасных
    self:_drawRow(player.charactersSpare, player.charactersSpareSize,
        "css_spare_", "BOTTOMLEFT", OFFSET, 0)

    -- 4. Ряд доступных для выбора
    UI.nextPosition("CENTER", "root")
    x = -widthSelect / 2
    y = 15 + BUTTON_SIZE
    self:_drawRow(self.charactersToSelect, self.selectCount,
        "css_toselect_", "BOTTOMLEFT", x, y)

    -- 5. Выделенное существо следует за курсором
    if self.selectedCharacter and self.selectedCharacter.sprite then
        local mx, my = love.mouse.getPosition()
        UI.nextPosition("TOPLEFT", "root")
        UI.image(mx, my, self.selectedCharacter.sprite.image, "CENTER", SPRITE_SCALE)
    end

    -- 6. Кнопка Continue
    UI.nextPosition("BOTTOM", "root")
    UI.setStyle({})
    if UI.button("css_continue", 0, -20, 200, 50, "Continue", "BOTTOM") then
        self:close()
    end
end

return CharacterSelectScreen