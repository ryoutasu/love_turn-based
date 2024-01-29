local neighbors_offset_even = {
    { 0, -1 },  -- up
    { -1, 0 },  -- left
    { 1,  0 },  -- right
    { 0,  1 },  -- down
    { 1,  1 },  -- up-right
    { 1, -1 }   -- down-right
}

local neighbors_offset_odd = {
    { 0, -1 },  -- up
    { -1, 0 },  -- left
    { 1,  0 },  -- right
    { 0,  1 },  -- down
    { -1, 1 },  -- up-left
    { -1, -1 }, -- down-left
}

local direction = {
    [-1] = {
        [-1] = 'SW',
        [0]  = math.pi*2, -- West
        [1]  = 'NW'
    },
    [0] = {
        [-1] = 3*math.pi/2, -- South
        [0] = 'NONE',
        [1] = math.pi -- North
    },
    [1] = {
        [-1] = 'SE',
        [0] = 0, -- East
        [1] = 'NE'
    }
}


function get_direction(x, y)
    return direction[x][y]
end
