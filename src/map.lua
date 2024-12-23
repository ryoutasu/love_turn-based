local tile = require 'src.objects.tile'
local coord_mt = require 'lib.coord_table'

local Map = Class{}

local map_offset_x = 0
local map_offset_y = 0

HEX_OFFSET_X = 4
HEX_OFFSET_Y = 4

HEX_RADIUS = 60
HEX_HEIGHT = 0.7

local function is_point_inside_hex(x, y, cx, cy)
    local z = HEX_RADIUS + HEX_OFFSET_X;
    local px = math.abs(x - cx);
    local py = math.abs(y - cy);

    local px0 = 0
    local py0 = 0
    local px1 = 0
    local py1 = z * HEX_HEIGHT
    local px2 = z * math.sqrt(3) / 2
    local py2 = z / 2 * HEX_HEIGHT
    local px3 = z * math.sqrt(3) / 2
    local py3 = 0

    local p_angle_01 = (px0 - px) * (py1 - py) - (px1 - px) * (py0 - py)
    local p_angle_20 = (px2 - px) * (py0 - py) - (px0 - px) * (py2 - py)
    local p_angle_03 = (px0 - px) * (py3 - py) - (px3 - px) * (py0 - py)
    local p_angle_12 = (px1 - px) * (py2 - py) - (px2 - px) * (py1 - py)
    local p_angle_32 = (px3 - px) * (py2 - py) - (px2 - px) * (py3 - py)

    local is_inside_1 = (p_angle_01 * p_angle_12 >= 0) and (p_angle_12 * p_angle_20 >= 0)
    local is_inside_2 = (p_angle_03 * p_angle_32 >= 0) and (p_angle_32 * p_angle_20 >= 0)

    return is_inside_1 or is_inside_2;
end

local hex_height = 2*HEX_RADIUS
local hex_width = (math.sqrt(3)/2)*hex_height
local function grid_to_world(x, y)
    local worldx = (hex_width * (x-1)) + (HEX_OFFSET_X * (x-1))
    local worldy = (hex_height * 3/4 * (y-1)) * HEX_HEIGHT + (HEX_OFFSET_Y * (y-1))

    if y % 2 == 0 then worldx = worldx + hex_width/2 + HEX_OFFSET_X/2 end

    return worldx, worldy
end

function Map:init(width, height)
    self.tiles = coord_mt()

    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()

    local map_width = width * hex_width + (width-1) * HEX_OFFSET_X
    local map_height = height * hex_height * 3/4 * HEX_HEIGHT + (width-1) * HEX_OFFSET_Y

    local startx = window_width / 2 - map_width / 2 + hex_width / 2 + map_offset_x
    local starty = window_height / 2 - map_height / 2 + hex_height / 2 + map_offset_y

    for j = 1, height do
        for i = 1, width do
            local x, y = grid_to_world(i, j)
            x = x + startx
            y = y + starty
            self.tiles[{i, j}] = tile(x, y, i, j)
        end
    end

    self.width = width
    self.height = height

    self.highlighted = nil
    -- self.entering_tile = nil
    -- self.leaving_tile = nil
    self.showing_range = false
end

function Map:reset_nodes()
    for k, t in pairs(self.tiles._props) do
        t:reset()
    end
    self.highlighted = nil
    self.showing_range = false
end

function Map:get_node(x, y)
    local t = self.tiles[{x, y}]
    return t
end

-- function Map:get_height_px()
--     local r = HEX_RADIUS * 2 * 3/4
--     return self.height * r + (self.height - 1) * HEX_OFFSET_Y
-- end

function Map:update(dt)
    -- self.entering_tile = nil
    -- self.leaving_tile = nil

    self:check_highlight_tile(love.mouse.getPosition())

    for k, t in pairs(self.tiles._props) do
        t:update(dt)
    end
end

function Map:draw()
    for k, t in pairs(self.tiles._props) do
        t:draw()
    end

    -- local window_width = love.graphics.getWidth()
    -- local window_height = love.graphics.getHeight()

    -- love.graphics.setColor(0, 0, 0, 1)
    -- love.graphics.line(0, window_height/2, window_width, window_height/2)
    -- love.graphics.line(window_width/2, 0, window_width/2, window_height)
end

function Map:check_highlight_tile(x, y)
    -- check if cursor is still inside highlighted tile
    local is_inside = self.highlighted and is_point_inside_hex(x, y, self.highlighted.x, self.highlighted.y) or false

    if is_inside then return end

    local leaving_tile
    local entering_tile
    -- if there is highlighted tile, then cursor left it
    if self.highlighted then
        leaving_tile = self.highlighted

        if BattleState.state == 'waiting' or BattleState.state == 'spell' then
            self.highlighted:hide_path()
        end

        self.highlighted = nil
    end

    for _, tile in pairs(self.tiles._props) do
        tile.cursor_inside = false
        tile.aoe_target = false

        is_inside = is_point_inside_hex(x, y, tile.x, tile.y)

        if is_inside then
            self.highlighted = tile
            entering_tile = tile
        end

        tile:change_color()
    end

    if leaving_tile then
        -- local leaving_tile = self.leaving_tile
        -- print('Leaving tile '..leaving_tile.tx..'/'..leaving_tile.ty)
        if self.showing_range then
            BattleState:cancel_target_mode()
            leaving_tile:hide_path()
            
            self.highlighted = entering_tile
            self.showing_range = false
        end

        if leaving_tile.actor then
            leaving_tile.actor.show_name = false
            leaving_tile.actor.panel.highlighted = false
        end
    end
    
    if entering_tile then
        -- local entering_tile = self.entering_tile
        -- print('Entering tile '..entering_tile.tx..'/'..entering_tile.ty)
        self:cursor_enters_tile(entering_tile)
        
        if entering_tile.actor then
            entering_tile.actor.show_name = true
            entering_tile.actor.panel.highlighted = true
        end
    end
end

function Map:cursor_enters_tile(tile)
    local state = BattleState.state
    local actor = BattleState:current_actor()

    tile:highlight()

    if state == 'waiting' and tile.is_open then
        tile:show_path()
    end

    if (state == 'waiting' or state == 'spell') and tile.can_be_selected then
        -- if actor is melee, it can move and attack
        if actor.attack_range == 1 and tile.range > 1 then
            tile:show_path()
        end
        tile:set_animation('select', nil, { 1, 0, 0, 1 })
        
        local current_spell = BattleState.current_spell
        if current_spell and current_spell.type == 'AOE' then
            local selectable = {}
            
            self:reset_nodes()
            BattleState.pathfinder:calculate_range(tile, current_spell.radius)
            
            for _, node in pairs(self.tiles._props) do
                if node.range <= current_spell.radius then
                    selectable[#selectable+1] = node
                end
            end

            BattleState:set_target_mode(current_spell)

            for _, node in ipairs(selectable) do
                node.aoe_target = true
                node:change_color()
            end
            
            self.highlighted = tile
        end
    end
    
    if state == 'waiting' and tile.actor and tile.actor ~= actor then
        self:show_actor_movement_range(tile)
    end

    if state == 'drawing_path' then
        if tile ~= self.last_tile then
            if tile == actor.node then
                self.last_tile:hide_path()
                self:start_drawing_path(tile)
            else--if tile.is_open or tile.can_be_selected and actor.attack_range == 1 then
                self:update_drawing_path(tile)
            end
        end
    end
end

function Map:show_actor_movement_range(tile)
    local actor = tile.actor
    local open_nodes = {}
    local attack_nodes = {}
    
    local can_be_selected = tile.can_be_selected
    local range = tile.range
    self:reset_nodes()

    BattleState.pathfinder:calculate(tile, actor.movement_range, true, false)

    for _, node in pairs(self.tiles._props) do
        if node.is_open then
            table.insert(open_nodes, node)
        end
        if node.in_attack_range then
            table.insert(attack_nodes, node)
        end
    end

    BattleState:cancel_target_mode()

    for _, node in pairs(open_nodes) do
        node.show_as_range = true
        node:change_color()
    end
    for _, node in pairs(attack_nodes) do
        node.show_as_attack_range = true
    end
    
    self.showing_range = true
    self.highlighted = tile

    tile.can_be_selected = can_be_selected
    tile.range = range
    tile:change_color()
end

function Map:update_drawing_path(tile)
    local actor = BattleState:current_actor()
    local new_path = {}
    local cut_path = false
    local last_tile = actor.node
    for _, node in ipairs(self.drawing_path) do
        if tile == node then
            self.last_tile:hide_path()
            cut_path = true
            break
        end
        new_path[#new_path+1] = node
        last_tile = node
    end

    if not (tile.is_open or cut_path or (tile.can_be_selected and actor.attack_range == 1)) then
        return
    end

    self.drawing_path = new_path

    local movement_range = BattleState:current_actor().movement_range
    local max_range = movement_range - #new_path - 1
    if cut_path then
        tile.parent = last_tile
        tile:show_path()

        table.insert(self.drawing_path, tile)
        
        self.last_tile:set_animation()
        self.last_tile = tile
        BattleState:recalculate_path(tile, max_range)

        return
    end

    if self.last_tile.can_be_selected then
        return
    end

    if tile.range == 1 and tile.can_be_selected then
        tile:show_path()
        tile:set_animation('select', nil, { 1, 0, 0, 1 })

        self.last_tile:set_animation()
        self.last_tile = tile
        BattleState:recalculate_path(tile, 0)
        
        tile.parent = last_tile

        return
    end

    if tile.range == 1 and #new_path < movement_range then
        tile.parent = last_tile
        tile:show_path()

        table.insert(self.drawing_path, tile)
        
        self.last_tile:set_animation()
        self.last_tile = tile
        BattleState:recalculate_path(tile, max_range)

        return
    end
end

function Map:start_drawing_path(tile)
    BattleState.state = 'drawing_path'

    local new_path = {}
    if tile.is_open or tile.can_be_selected then
        local path = tile:get_path()
        for _, t in ipairs(path) do
            table.insert(new_path, t)
        end
    end
    self.drawing_path = new_path
    self.last_tile = tile

    local movement_range = BattleState:current_actor().movement_range
    local max_range = movement_range - #self.drawing_path
    -- print('#self.drawing_path = ',#self.drawing_path)
    
    -- if tile.can_be_selected then
    --     max_range = 0
    -- end

    BattleState:recalculate_path(tile, max_range)
end

function Map:stop_drawing_path()
    self.last_tile:hide_path()
    BattleState:cancel_target_mode()
    self.drawing_path = {}
end

return Map