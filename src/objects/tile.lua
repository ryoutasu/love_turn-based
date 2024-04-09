require 'src.direction'
local sprite = require 'src.sprite'
local tileAnimation = require 'src.tile_animation'

local Tile = Class{}

function Tile:init(x, y, tx, ty, cost)
    self.x = x
    self.y = y
    self.tx = tx
    self.ty = ty

    self.cost = cost or 1
    self.parent = nil
    self.is_open = false

    self.actor = nil
    self.cursor_inside = false
    self.acting = false
    self.as_path = false
    self.path_sprite = sprite('resources/arrow.png')
    self.path_with_cursor_sprite = sprite('resources/selecting.png')
    self.timer = 0
    self.max_time = 0
    self.path_sprite_rotation = 0
    self.can_be_selected = false
    self.range = nil
    self.show_as_range = false
    self.aoe_target = false
    self.borders = { false, false, false, false, false, false }
    
    self:change_color()
end

function Tile:reset()
    self.parent = nil
    self.drawing_path_parent = nil
    self.is_open = false
    self.acting = false
    self.can_be_selected = false
    self.range = nil
    self.show_as_range = false
    self.aoe_target = false
    self.borders = { false, false, false, false, false, false }

    self:change_color()
end

function Tile:change_color()
    -- if self.is_open and self.cursor_inside then
    --     self.color_id = COLOR_ID.BRIGHT_YELLOW

    -- elseif self.is_open then
    --     self.color_id = COLOR_ID.YELLOW

    -- elseif self.acting and self.cursor_inside then
    --     self.color_id = COLOR_ID.LIGHT_GREEN

    -- elseif self.acting then
    --     self.color_id = COLOR_ID.GREEN

    -- elseif self.can_be_selected and self.cursor_inside then
    --     self.color_id = COLOR_ID.RED
        
    -- elseif self.can_be_selected then
    --     self.color_id = COLOR_ID.BRIGHT_RED

    -- else
    --     if self.cursor_inside then
    --         self.color_id = COLOR_ID.DARK_GREY
    --     else
    --         self.color_id = COLOR_ID.TRANSPARENT_GREY
    --     end
    -- end
    
    local color
    if self.is_open and self.show_as_range then
        color = TILE_COLOR[COLOR_ID.SHADE_DARK_GREEN]
    elseif self.is_open or self.aoe_target then
        color = TILE_COLOR[COLOR_ID.SHADE_GREEN]
    elseif self.show_as_range then
        color = TILE_COLOR[COLOR_ID.SHADE_LIGHT_BLUE]
    -- elseif self.acting then
    --     color = TILE_COLOR[COLOR_ID.GREEN]
    elseif self.can_be_selected then
        color = TILE_COLOR[COLOR_ID.BRIGHT_RED]
    else
        color = TILE_COLOR[COLOR_ID.TRANSPARENT_GREY]
    end

    if self.cursor_inside then
        self.color = Urutora.utils.brighter(color, 0.35)
    else
        self.color = color
    end
end

function Tile:open_to_move()
    self.is_open = true
    if BattleState.state == 'waiting' or BattleState.state == 'drawing_path' then
        self:change_color()
    end
end

function Tile:highlight()
    self.cursor_inside = true
    self:change_color()
end

function Tile:unhighlight()
    self.cursor_inside = false
    self:change_color()
end

function Tile:set_animation(anim, time, color)
    if not anim then
        self.animation = nil
    else
        self.animation = tileAnimation(anim, self.x, self.y, time, color)
    end
end

function Tile:set_path_sprite_direction(next_node)
    local dx, dy = next_node.x - self.x, next_node.y - self.y

    local r = Vector(dx, dy):angleTo()
    self.path_sprite_rotation = r
end

function Tile:get_path()
    local path = {}
    local current = self
    repeat
        table.insert(path, 1, current)
        current = current.parent
    until not current.parent
    return path
end

function Tile:show_path(first)
    if self.parent then
        -- if self.parent == self then print('ABORT!'); return end
        -- if self.parent.parent == self then print('ABORT! 2'); return end
        self.parent:set_path_sprite_direction(self)
        self.as_path = first or 'first'
        if not first then
            self:set_animation('select')
        end
        self.parent:show_path(true)
    end
end

function Tile:hide_path()
    self.as_path = false
    self:set_animation()
    if self.parent then
        -- if self.parent == self then print('ABORT!'); return end
        -- if self.parent.parent == self then print('ABORT! 2'); return end
        self.parent:hide_path()
    end
end

function Tile:update(dt)
    if self.animation then
        self.animation:update(dt)
    end
end

local function get_hex_points(x, y)
    local points = {}
    for i = 0, 5 do
        local angle_deg = 60 * i + 30
		local angle_rad = math.pi / 180 * angle_deg

		local px = x + HEX_RADIUS * math.cos(angle_rad)
		local py = y + HEX_RADIUS * math.sin(angle_rad)

        table.insert(points, px)
        table.insert(points, py)
    end

    return points
end

local function get_borders_points(x, y, n)
    local points = {}

    for i = n, n + 1 do
        local angle_deg = 60 * i + 30
		local angle_rad = math.pi / 180 * angle_deg

		local px = x + (HEX_RADIUS + HEX_OFFSET_X/2) * math.cos(angle_rad)
		local py = y + (HEX_RADIUS + HEX_OFFSET_Y/2) * math.sin(angle_rad)

        table.insert(points, px)
        table.insert(points, py)
    end

    return points
end

function Tile:draw()
    local x, y = self.x, self.y
    local points = get_hex_points(x, y)
    -- local color = TILE_COLOR[self.color_id]

    local color = self.color
    love.graphics.setColor(color)
    love.graphics.polygon('fill', points)
    -- color = OUTLINE_COLOR[self.color_id]

    color = Urutora.utils.darker(color, 1)
    love.graphics.setColor(color)
    love.graphics.polygon('line', points)

    for i, value in ipairs(self.borders) do
        if value then
            points = get_borders_points(x, y, i)
            
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.line(points)
        end
    end

    if self.animation then
        self.animation:draw()
    end

    if self.as_path == true then
        local s = self.path_sprite
        love.graphics.setColor(1, 1, 1, 1)
        s:draw(_, x, y, self.path_sprite_rotation, 1, 1, s.w/2, s.h/2)
    end

    -- if self.range then
    --     love.graphics.setColor(0, 0, 0, 1)
    --     love.graphics.setNewFont(12)
    --     love.graphics.print(self.range, self.x, self.y)
    -- end
    -- if self.parent then
    --     love.graphics.setColor(0, 0, 0, 1)
    --     love.graphics.setNewFont(12)
    --     love.graphics.print(tostring(self.tx..'/'..self.ty), self.x-8, self.y-12)
    --     love.graphics.print(tostring('p='..self.parent.tx..'/'..self.parent.ty), self.x-20, self.y)
    -- end
    -- love.graphics.setColor(0, 0, 0, 1)
    -- love.graphics.setNewFont(12)
    -- love.graphics.print(tostring(self.tx..'/'..self.ty), self.x-8, self.y-6)
end

return Tile