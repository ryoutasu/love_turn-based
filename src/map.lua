local tile = require 'src.objects.tile'
local coord_mt = require 'lib.coord_table'

local Map = Class{}

local startx = 64
local starty = 64

local offsetx = 4
local offsety = 4

HEX_RADIUS = 32

local function is_point_inside_hex(x, y, cx, cy)
    local z = HEX_RADIUS;
    local px = math.abs(x - cx);
    local py = math.abs(y - cy);

    local px0 = 0
    local py0 = 0
    local px1 = 0
    local py1 = z
    local px2 = z * math.sqrt(3) / 2
    local py2 = z / 2
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

local function grid_to_world(x, y)
    local height = 2*HEX_RADIUS
    local width = (math.sqrt(3)/2)*height

    local worldx = (width * (x-1)) + (offsetx * (x-1)) + startx
    local worldy = (height * 3/4 * (y-1)) + (offsety * (y-1)) + starty

    if y % 2 == 0 then worldx = worldx + width/2 + offsetx/2 end

    return worldx, worldy
end

function Map:init(width, height)
    print('map init')
    self.tiles = coord_mt()

    for j = 1, height do
        for i = 1, width do
            local x, y = grid_to_world(i, j)
            self.tiles[{i, j}] = tile(x, y, i, j)
        end
    end

    self.width = width
    self.height = height

    self.highlighted = nil
    self.entering_tile = nil
    self.leaving_tile = nil
end

function Map:reset_nodes()
    for k, t in pairs(self.tiles._props) do
        t:reset()
    end
    self.highlighted = nil
end

function Map:get_node(x, y)
    local t = self.tiles[{x, y}]
    return t
end

function Map:get_height_px()
    local r = HEX_RADIUS * 2 * 3/4
    return starty + self.height * r + (self.height - 1) * offsety
end

function Map:update(dt)
    self.entering_tile = nil
    self.leaving_tile = nil

    self:check_highlight_tile(love.mouse.getPosition())

    for k, t in pairs(self.tiles._props) do
        t:update(dt)
    end
end

function Map:draw()
    for k, t in pairs(self.tiles._props) do
        t:draw()
    end
end

function Map:check_highlight_tile(x, y)
    -- check if cursor is still inside highlighted tile
    local is_inside = self.highlighted and is_point_inside_hex(x, y, self.highlighted.x, self.highlighted.y) or false

    if is_inside then return end
    
    -- if there is highlighted tile, then cursor left it
    if self.highlighted then
        self.leaving_tile = self.highlighted

        if BattleState.state == 'waiting' or BattleState.state == 'spell' then
            self.highlighted:hide_path()
        end

        self.highlighted:unhighlight()
        self.highlighted = nil
    end

    for i, tile in pairs(self.tiles._props) do
        is_inside = is_point_inside_hex(x, y, tile.x, tile.y)
        
        if is_inside then
            self.highlighted = tile
            self.entering_tile = tile
        end
    end
    
    if self.entering_tile then
        self:cursor_enters_tile(self.entering_tile)
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

function Map:update_drawing_path(tile)
    -- TODO: use 'calculate' instead of 'calculate_range' to show proper path
    local actor = BattleState:current_actor()
    local new_path = {}
    local cut_path = false
    local last_tile = BattleState:current_actor().node
    for _, node in ipairs(self.drawing_path) do
        if tile == node then
            self.last_tile:hide_path()
            cut_path = true
            break
        end
        new_path[#new_path+1] = node
        last_tile = node
    end

    if not (tile.is_open or tile.can_be_selected and actor.attack_range == 1 or cut_path) then
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
        BattleState.pathfinder:calculate_range(tile, max_range)
        -- BattleState:recalculate_path(tile, movement_range - #new_path)

        return
    end

    if self.last_tile.can_be_selected then
        return
    end

    if tile.range == 1 and tile.can_be_selected then
        tile.parent = last_tile
        tile:show_path()
        tile:set_animation('select', nil, { 1, 0, 0, 1 })

        self.last_tile:set_animation()
        self.last_tile = tile
        BattleState.pathfinder:calculate_range(tile, 0)
        -- BattleState:recalculate_path(tile, 0)

        return
    end

    if tile.range == 1 and #new_path < movement_range then
        tile.parent = last_tile
        tile:show_path()

        table.insert(self.drawing_path, tile)
        
        self.last_tile:set_animation()
        self.last_tile = tile
        BattleState.pathfinder:calculate_range(tile, max_range)
        -- BattleState:recalculate_path(tile, movement_range - #new_path)

        return
    end
end

function Map:start_drawing_path(tile)
    BattleState.state = 'drawing_path'
    self.drawing_path = {}
    if tile.is_open then
        local path = tile:get_path()
        for _, t in ipairs(path) do
            table.insert(self.drawing_path, t)
        end
    end
    self.last_tile = tile
    
    local movement_range = BattleState:current_actor().movement_range
    local max_range = movement_range - #self.drawing_path
    BattleState.pathfinder:calculate_range(tile, max_range)
    -- BattleState:recalculate_path(tile, max_range)
end

function Map:stop_drawing_path()
    self.last_tile:hide_path()
    BattleState:cancel_target_mode()
    self.drawing_path = {}
end

return Map