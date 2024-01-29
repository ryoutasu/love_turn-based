local TileAnim = Class{}

local select_anim_max_time = 1.5
local fill_anim_max_time = 3

local function get_select_points(x, y, t)
    local size = HEX_RADIUS - 2
    local line_length = size / 3
    local offset = line_length * t/select_anim_max_time*3

    local px = x
    local py = y - size
    local angle_deg = 30
    local angle_rad = math.pi / 180 * angle_deg
    local first_line_length = line_length * 2

    local d = offset
    if offset > line_length then
        first_line_length = first_line_length - offset + line_length
    end

    local lines = {}
    for i = 0, 5 do
        local points = {}
        for j = 0, 2 do
            if j == 0 then
                d = offset

            elseif j == 1 then
                d = first_line_length

            elseif j == 2 then
                d = line_length*2 - first_line_length

                if offset > line_length then
                    angle_deg = angle_deg + 60
                    angle_rad = math.pi / 180 * angle_deg
                end
            end

            px = px + math.cos(angle_rad) * d
            py = py + math.sin(angle_rad) * d

            table.insert(points, px)
            table.insert(points, py)
        end
        d = size - offset - first_line_length
        if offset > line_length then
            d = line_length - offset
        end
        px = px + math.cos(angle_rad) * d
        py = py + math.sin(angle_rad) * d

        if offset < line_length then
            angle_deg = angle_deg + 60
            angle_rad = math.pi / 180 * angle_deg
        end

        table.insert(lines, points)
    end

    return lines
end

local function get_border_fill_points(x, y, t)
    local size = HEX_RADIUS - 2
    local time_per_side = fill_anim_max_time/6

    local angle_deg = -30
    local angle_rad = math.pi / 180 * angle_deg

    local px = x
    local py = y - size

    local points = {}
    table.insert(points, px)
    table.insert(points, py)
    local i = 0
    while t > 0 do
        local diff = math.min(t, time_per_side)
        local d = diff / time_per_side * size
        
        angle_deg = angle_deg + 60
        angle_rad = math.pi / 180 * angle_deg
        
        px = px + math.cos(angle_rad) * d
        py = py + math.sin(angle_rad) * d
        
        table.insert(points, px)
        table.insert(points, py)
        
        t = t - diff
        i = i + 1
    end

    if i == 0 then return nil end
    return points
end

local animation = {
    ['select'] = {
        func = function (x, y, t)
            local lines = get_select_points(x, y, t)
            for i, p in ipairs(lines) do
                love.graphics.line(p[1], p[2], p[3], p[4])
                if p[3] ~= p[5] or p[4] ~= p[6] then
                    love.graphics.line(p[3], p[4], p[5], p[6])
                end
            end
        end,
        time = 1.5,
        color = { 0.1, 0.22, 0.1, 1 }
    },
    ['border_fill'] = {
        func = function (x, y, t)
            local p = get_border_fill_points(x, y, t)
            if p then love.graphics.line(p) end
        end,
        time = 3,
        color = { 1, 0, 0, 1 }
    }
}

function TileAnim:init(type, x, y, time, color)
    self.timer = 0
    self.func = animation[type].func
    self.time = time or animation[type].time
    self.color = color or animation[type].color
    self.x = x
    self.y = y
end

function TileAnim:update(dt)
    self.timer = self.timer + dt
    if self.timer > self.time then
        self.timer = 0
    end
end

function TileAnim:draw()
    local old_width = love.graphics.getLineWidth()
    love.graphics.setColor(self.color)
    love.graphics.setLineWidth(3)

    self.func(self.x, self.y, self.timer)

    love.graphics.setLineWidth(old_width)
end

return TileAnim