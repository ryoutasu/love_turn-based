local ui = {
    anchors = {
        TOPLEFT     = {0.0, 0.0},
        TOP         = {0.5, 0.0},
        TOPRIGHT    = {1.0, 0.0},
        LEFT        = {0.0, 0.5},
        CENTER      = {0.5, 0.5},
        RIGHT       = {1.0, 0.5},
        BOTTOMLEFT  = {0.0, 1.0},
        BOTTOM      = {0.5, 1.0},
        BOTTOMRIGHT = {1.0, 1.0}
    },
}

local images = {}

local default_style = {
    draw_border = false,
    border_width = 1,
    border_color = { 1, 1, 1, 1 },

    disabled_color = { 0.5, 0.5, 0.5, 0.45 },
    disabled_text_color = { 0.35, 0.35, 0.35, 0.55 },

    background_color = { 0.5, 0.5, 0.9 },
    corner_radius = 7,

    text_color = { 1, 1, 1, 1 }
}
ui.style = default_style

local default_anchor = ui.anchors.TOPLEFT

local default_font = love.graphics.newFont(14)
local current_font = default_font

local states = {}
local to_draw = {}

local active_input = nil
local cursor_blink = 0
local cursor_visible = false

local mousebuttons = {
    [1] = {},
    [2] = {},
    [3] = {},
}

local current_pos = { x = 0, y = 0 }

-- local shader = require "shader"(false)

local function darker(color, amount)
    amount = 1 - (amount or 0.2)
    local r, g, b = color[1], color[2], color[3]
    r = r * amount
    g = g * amount
    b = b * amount

    return { r, g, b, color[4] }
end

local function brighter(color, amount)
    amount = amount or 0.2
    local r, g, b = color[1], color[2], color[3]
    r = r + ((1 - r) * amount)
    g = g + ((1 - g) * amount)
    b = b + ((1 - b) * amount)

    return { r, g, b, color[4] }
end

local function assertAnchor(anchor)
    if type(anchor) == "string" then
        anchor = ui.anchors[anchor]
    end
    anchor = anchor or default_anchor
    assert(type(anchor) == "table", "Wrong anchor type!")
    return anchor
end

-- Преобразование координат на основе якоря
local function applyAnchor(x, y, w, h, anchor)
    local ax, ay = anchor[1], anchor[2]
    return x - w * ax, y - h * ay
end

-- Переработанная функция проверки взаимодействия
local function checkInteraction(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    return (mx >= x and mx <= x + w and my >= y and my <= y + h)
end

function ui.clear()
    to_draw = { { id = "root", type = "root", x = 0, y = 0, w = love.graphics.getWidth(), h = love.graphics.getHeight() } }
    current_pos = { x = 0, y = 0 }
    ui.setStyle()
    ui.setFont()
end

function ui.button(id, x, y, w, h, label, anchor, enabled)
    if enabled == nil then enabled = true end
    anchor = assertAnchor(anchor)
    local rx, ry = applyAnchor(x, y, w, h, anchor)
    rx = rx + current_pos.x
    ry = ry + current_pos.y

    local state = states[id] or { hovered = false, pressed = false, released = false }

    state.hovered = checkInteraction(rx, ry, w, h) and enabled
    
    local object = {
        type = "button",
        id = id,
        x = rx, y = ry, w = w, h = h,
        label = label,
        state = state,
        anchor = anchor,
        style = ui.style,
        font = current_font,
        enabled = enabled,
    }

    table.insert(to_draw, object)
    states[id] = state

    if state.released then
        state.hovered = false
    end

    return state.released
end

function ui.text(x, y, text, anchor, color, font, outline_color, outline_size)
    local font = font or current_font
    local text = love.graphics.newText(font, text)
    local w, h = text:getWidth(), text:getHeight()
    anchor = assertAnchor(anchor)
    local rx, ry = applyAnchor(x, y, w, h, anchor)
    rx = rx + current_pos.x
    ry = ry + current_pos.y
    
    table.insert(to_draw, {
        type = "text",
        x = rx, y = ry, w = w, h = h,
        -- text = text,
        text = text,
        color = color or {1, 1, 1},
        font = font,
        outline_color = outline_color,
        outline_size = outline_size,
    })
end

function ui.backdrop(id, x, y, w, h, anchor, color)
    anchor = assertAnchor(anchor)
    local rx, ry = applyAnchor(x, y, w, h, anchor)
    rx = rx + current_pos.x
    ry = ry + current_pos.y

    local state = states[id] or { hovered = false, pressed = false, released = false }

    state.hovered = checkInteraction(rx, ry, w, h)
    
    local object = {
        type = "backdrop",
        id = id,
        x = rx, y = ry, w = w, h = h,
        state = state,
        anchor = anchor,
        style = ui.style,
        color = color,
    }

    table.insert(to_draw, object)
    states[id] = state

    return state.hovered
end

function ui.image(x, y, image_or_path, anchor, size, color)
    local image = image_or_path
    if type(image) == "string" then
        if not images[image] then
            images[image] = love.graphics.newImage(image)
        end
        image = images[image]
    end
    local w = image:getWidth() * size
    local h = image:getHeight() * size

    anchor = assertAnchor(anchor)
    local rx, ry = applyAnchor(x, y, w, h, anchor)
    rx = rx + current_pos.x
    ry = ry + current_pos.y

    -- local state = states[id] or { hovered = false, pressed = false, released = false }

    -- state.hovered = checkInteraction(rx, ry, w, h)
    
    local object = {
        type = "image",
        -- id = id,
        x = rx, y = ry, w = w, h = h,
        image = image,
        -- state = state,
        anchor = anchor,
        color = color or { 1, 1, 1, 1 },
        size = size,
    }

    table.insert(to_draw, object)
    -- states[id] = state
end

function ui.inputText(id, x, y, w, h, text, anchor, font)
    local font = font or current_font
    anchor = assertAnchor(anchor)
    local rx, ry = applyAnchor(x, y, w, h, anchor)
    
    rx = rx + current_pos.x
    ry = ry + current_pos.y
    
    -- Инициализация состояния
    if not states[id] then
        states[id] = {
            text = text or "",
            cursorPos = #(text or ""),
            hovered = false,
            active = false
        }
    end
    
    local state = states[id]
    local object = {
        type = "inputText",
        id = id,
        x = rx, y = ry, w = w, h = h,
        text = state.text,
        state = state,
        anchor = anchor,
        style = ui.style,
        font = font,
    }
    
    -- Проверка взаимодействия
    local hovered = checkInteraction(rx, ry, w, h)
    state.hovered = hovered
    
    if mousebuttons[1].pressed and state.active then
        -- Расчет позиции курсора по клику
        local mx, my = love.mouse.getPosition()
        local clickX = mx - rx - 4
        local textWidth = 0
        local newPos = 0
        
        for i = 1, #state.text do
            local char = state.text:sub(i, i)
            local charWidth = font:getWidth(char)
            textWidth = textWidth + charWidth
            
            if clickX <= textWidth - charWidth / 2 then
                newPos = i - 1
                break
            end
            
            if i == #state.text then
                newPos = i
            end
        end
        
        state.cursorPos = newPos
        cursor_visible = true
        cursor_blink = 0
    end

    table.insert(to_draw, object)
    return state.text
end

function ui.bar(id, x, y, w, h, fill, fill_color, anchor)
    anchor = assertAnchor(anchor or "CENTER")
    local rx, ry = applyAnchor(x, y, w, h, anchor)
    
    rx = rx + current_pos.x
    ry = ry + current_pos.y
    
    local object = {
        type = "bar",
        id = id,
        x = rx, y = ry, w = w, h = h,
        anchor = anchor,
        style = ui.style,
        fill = fill,
        fill_color = fill_color,
    }

    table.insert(to_draw, object)
end

-- round button for levelmap
function ui.node(id, x, y, radius, image_or_path, enabled)
    local image = image_or_path
    if type(image) == "string" then
        if not images[image] then
            images[image] = love.graphics.newImage(image)
        end
        image = images[image]
    end

    local rx = x - radius
    local ry = y - radius
    local w = radius + radius
    local h = radius + radius

    local state = states[id] or { hovered = false, pressed = false, released = false, wasHovered = false }

    state.hovered = checkInteraction(rx, ry, w, h) and enabled

    local object = {
        type = "node",
        id = id,
        x = rx, y = ry, w = w, h = h, radius = radius,
        state = state,
        image = image,
        enabled = enabled,
        style = ui.style,
    }

    table.insert(to_draw, object)
    states[id] = state

    -- if state.released then
    --     state.hovered = false
    -- end

    return state.released, state.wasHovered
end

function ui.update(dt)
    cursor_blink = cursor_blink + dt
    if cursor_blink > 0.5 then
        cursor_blink = 0
        cursor_visible = not cursor_visible
    end

    for index, button in ipairs(mousebuttons) do
        button.pressed = false
        button.released = false

        if love.mouse.isDown(index) then
            if not button.held then
                button.pressed = true
            end

            button.held = true
        else
            if button.held then
                button.released = true
            end
            
            button.held = false
        end
    end

    for id, state in pairs(states) do
        state.released = false
        
        if state.hovered then
            if state.pressed and mousebuttons[1].released then
                state.released = true
                state.pressed = false
            end

            if mousebuttons[1].pressed then
                state.pressed = true

                state.active = true
                active_input = id
            end
        end

        if mousebuttons[1].released and not state.hovered then
            state.pressed = false
        end

        if state.active and mousebuttons[1].pressed and not state.hovered then
            active_input = nil
            state.active = false
        end

        state.wasHovered = state.hovered
    end

    -- to_draw = { { id = "root", type = "root", x = 0, y = 0, w = love.graphics.getWidth(), h = love.graphics.getHeight() } }
    -- current_pos = { x = 0, y = 0 }
    -- ui.setStyle()
    -- ui.setFont()
    ui.clear()
end

-- Обработчик ввода текста (вызывать в love.textinput)
function ui.handleTextInput(t)
    if active_input and states[active_input] then
        local state = states[active_input]
        state.text = state.text:sub(1, state.cursorPos) .. t .. state.text:sub(state.cursorPos + 1)
        state.cursorPos = state.cursorPos + #t
        cursor_visible = true
        cursor_blink = 0
    end
end

-- Обработчик нажатия клавиш (вызывать в love.keypressed)
function ui.handleKeyPress(key)
    if not active_input then return end
    local state = states[active_input]
    if not state then return end

    cursor_visible = true
    cursor_blink = 0

    if key == "backspace" then
        if state.cursorPos > 0 then
            state.text = state.text:sub(1, state.cursorPos - 1) .. state.text:sub(state.cursorPos + 1)
            state.cursorPos = state.cursorPos - 1
        end
    elseif key == "delete" then
        if state.cursorPos < #state.text then
            state.text = state.text:sub(1, state.cursorPos) .. state.text:sub(state.cursorPos + 2)
        end
    elseif key == "left" then
        if state.cursorPos > 0 then
            state.cursorPos = state.cursorPos - 1
        end
    elseif key == "right" then
        if state.cursorPos < #state.text then
            state.cursorPos = state.cursorPos + 1
        end
    elseif key == "home" then
        state.cursorPos = 0
    elseif key == "end" then
        state.cursorPos = #state.text
    elseif key == "return" or key == "kpenter" or key == "escape" then
        -- По нажатию Enter снимаем фокус
        active_input = nil
        state.active = false
    end
end

    local outlinetextcoords = {
        { -1, 0 },
        { 1, 0 },
        { 0, -1 },
        { 0, 1 },
        
        { 1, 1 },
        { 1, -1 },
        { -1, 1 },
        { -1, -1 },
    }

function ui.draw()
    local hovered_state
    for index, object in ipairs(to_draw) do
        local state = object.state
        if state then
            if state.hovered then
            hovered_state = state
            state.hovered = false
            end

            if object.type ~= "inputText" and state.active then
                state.active = false
                active_input = nil
            end
        end
    end
    if hovered_state then
        hovered_state.hovered = true
    end

    for index, object in ipairs(to_draw) do
        local x, y = math.ceil(object.x), math.ceil(object.y)
        if object.type == "button" then
            local w, h = object.w, object.h
            local corner_radius = object.style.corner_radius
            local color = object.style.background_color
            if not object.enabled then
                color = object.style.disabled_color
            else
                if object.state.pressed then
                    color = darker(color)

                    -- изменение размера при нажатии
                    -- x = x + w/2
                    -- y = y + h/2
                    -- w = w * 0.95
                    -- h = h * 0.95
                    -- x = x - w/2
                    -- y = y - h/2
                elseif object.state.hovered then
                    color = brighter(color)
                end
            end

            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, y, w, h, corner_radius, corner_radius)

            if object.style.draw_border then
                love.graphics.setLineWidth(object.style.border_width)
                love.graphics.setColor(object.style.border_color)
                love.graphics.rectangle("line", x, y, w, h, corner_radius, corner_radius)
            end

            local height = object.font:getHeight()
            love.graphics.setFont(object.font)
            if not object.enabled then
                love.graphics.setColor(object.style.disabled_text_color)
            else
                love.graphics.setColor(object.style.text_color)
            end
            love.graphics.printf(object.label, x, math.ceil(y + object.h/2 - height/2), object.w, "center")
        elseif object.type == "text" then
            if object.outline_color then
                local size = object.outline_size
                love.graphics.setColor(object.outline_color)
                for _, value in ipairs(outlinetextcoords) do
                    love.graphics.draw(object.text, x + value[1] * size, y + value[2] * size)
                end
            end

            love.graphics.setColor(object.color or object.style.text_color)
            -- love.graphics.print(object.text, math.ceil(object.x), math.ceil(object.y))
            love.graphics.draw(object.text, x, y)
        elseif object.type == "backdrop" then
            local corner_radius = object.style.corner_radius
            local color = object.color or object.style.background_color
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, y, object.w, object.h, corner_radius, corner_radius)

            if object.style.draw_border then
                love.graphics.setLineWidth(object.style.border_width)
                love.graphics.setColor(object.style.border_color)
                love.graphics.rectangle("line", x, y, object.w, object.h, corner_radius, corner_radius)
            end
        elseif object.type == "image" then
            love.graphics.setColor(object.color)
            love.graphics.draw(object.image, x, y, 0, object.size, object.size)
        elseif object.type == "inputText" then
            -- Рисуем фон
            if object.state.active then
                love.graphics.setColor(1, 1, 1) -- Активное поле
            elseif object.state.hovered then
                love.graphics.setColor(0.95, 0.95, 0.95) -- При наведении
            else
                love.graphics.setColor(0.9, 0.9, 0.9) -- Неактивное поле
            end
            love.graphics.rectangle("fill", x, y, object.w, object.h)
            
            -- Рамка
            if object.state.active then
                love.graphics.setColor(0.2, 0.5, 1) -- Синяя рамка для активного поля
            else
                love.graphics.setColor(0.7, 0.7, 0.7) -- Серая рамка
            end
            love.graphics.rectangle("line", x, y, object.w, object.h)
            
            -- Текст
            love.graphics.setColor(0.1, 0.1, 0.1)
            local font = object.font
            love.graphics.setFont(font)
            love.graphics.print(object.text, x + 4, y + (object.h - font:getHeight()) / 2)
            
            -- Курсор (только для активного поля)
            if object.state.active and cursor_visible then
                local cursorX = x + 4 + font:getWidth(object.text:sub(1, object.state.cursorPos))
                love.graphics.setColor(0.1, 0.1, 0.1)
                love.graphics.line(cursorX, y + 4, cursorX, y + object.h - 4)
            end
        elseif object.type == "bar" then
            local corner_radius = object.style.corner_radius
            local color = object.style.background_color

            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, y, object.w, object.h, corner_radius, corner_radius)

            local fill_size = object.w * object.fill
            local sx, sy, sw, sh = love.graphics.getScissor()
            love.graphics.setScissor(x, y, fill_size, object.h)
            love.graphics.setColor(object.fill_color)
            love.graphics.rectangle("fill", x, y, object.w, object.h, corner_radius, corner_radius)
            love.graphics.setScissor(sx, sy, sw, sh)

            if object.style.draw_border then
                love.graphics.setLineWidth(object.style.border_width)
                love.graphics.setColor(object.style.border_color)
                love.graphics.rectangle("line", x, y, object.w, object.h, corner_radius, corner_radius)
            end
        elseif object.type == "node" then
            local radius = object.radius
            x, y = x + radius, y + radius
            local size = 1
            if object.state.hovered then
                size = 1.2
                radius = radius * size
            end

            love.graphics.setColor(object.style.background_color)
            love.graphics.circle("fill", x, y, radius)

            if object.image and object.enabled then
                love.graphics.setColor(1, 1, 1, 1)
                local w, h = object.image:getWidth(), object.image:getHeight()
                love.graphics.draw(object.image, x - radius, y - radius, 0, radius / w * 2, radius / h * 2)
            end

            love.graphics.setLineWidth(object.style.border_width)
            love.graphics.setColor(object.style.border_color)
            love.graphics.circle("line", x, y, radius)
        end
    end
    
    -- ui.clear()
end

function ui.setStyle(new_style)
    new_style = new_style or {}
    ui.style = default_style
    local t = {}
    for k, v in pairs(ui.style) do
        t[k] = v
    end
    for k, v in pairs(new_style) do
        t[k] = v
    end
    ui.style = t
end

function ui.nextPosition(anchor, object, x, y)
    x, y = x or 0, y or 0
    if type(object) == "string" then
        for index, value in ipairs(to_draw) do
            if value.id == object then
                object = value
                break
            end
        end
    end

    if not object then
        object = to_draw[#to_draw]
    end

    anchor = assertAnchor(anchor)
    local ax, ay = anchor[1], anchor[2]
    local rx, ry = object.x + object.w * ax + x, object.y + object.h * ay + y

    current_pos = { x = rx, y = ry }
end

function ui.setFont(font)
    if not font then font = default_font end
    if type(font) == "number" then
        font = love.graphics.newFont(font)
    end
    current_font = font
end

function ui.getMouseButton(button)
    return mousebuttons[button]
end

return ui