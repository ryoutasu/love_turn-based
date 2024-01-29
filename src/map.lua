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
    for k, t in pairs(self.tiles._props) do
        t:update(dt)
    end
end

function Map:draw()
    for k, t in pairs(self.tiles._props) do
        t:draw()
    end
end

function Map:mousepressed(x, y)
end

function Map:check_highlight_tile(x, y)
    local is_inside = self.highlighted and is_point_inside_hex(x, y, self.highlighted.x, self.highlighted.y) or false

    if is_inside then return end
    
    if BattleState.state == 'waiting' or BattleState.state == 'spell' then
        if self.highlighted then
            self.highlighted:hide_path()
            self.highlighted = nil
        end
    end

    for k, t in pairs(self.tiles._props) do
        is_inside = is_point_inside_hex(x, y, t.x, t.y)
        
        if is_inside then
            t:highlight()
            if t.is_open then
                t:show_path()
            end
            if t.can_be_selected then
                if BattleState:current_actor().attack_range == 1 and t.range > 1 then
                    t:show_path()
                end
                t:set_animation('select', nil , { 1, 0, 0, 1 })
            end
            self.highlighted = t
        elseif t.cursor_inside then
            t:unhighlight()
        end
    end
end


function Map:mousemoved(x, y, dx, dy)
    self:check_highlight_tile(x, y)
end

return Map