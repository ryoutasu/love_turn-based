local damage = 10
local slow = 2
local duration = 2

local SpikeTrap = Class{
    name = 'Spike Trap',
    description = 'Place a trap that deals ' .. damage .. ' damage and slows enemy.',

    usableOnMap = false,
    usableInFight = true,

    type = 'tile',
    radius = 0,
    range = 100,
    filter = function(target)
        return not target.is_blocked and #target.effects == 0
    end,
    color = { 0.6, 0.6, 0.6, 1 },
}

function SpikeTrap:init(caster, target)
    if Gamestate.current() == Levelmap then return end

    self.caster = caster
    self.target = target
    self.x = target.x
    self.y = target.y
    self.tile_size = 48  -- Adjust based on your tile size

    -- Add trap to tile
    target:add_effect({
        owner = caster,
        trigger = function(stepping_unit)
            if stepping_unit and not stepping_unit.is_player then
                stepping_unit:take_damage(self.caster, damage)
                stepping_unit:add_status_effect({
                    name = 'Trap Slow',
                    duration = duration,
                    caster = caster,
                    target = stepping_unit,
                    on_tick = function() end,
                    on_expire = function(self)
                        self.target:add_bonus_stat('initiative', slow)
                        -- stepping_unit:add_bonus_stat('move_range', -slow)
                    end
                })
                stepping_unit:add_bonus_stat('initiative', -slow)
                -- stepping_unit:add_bonus_stat('move_range', -slow)
                return true
            end
        end,
        update = function (dt) end,
        draw = function ()
            -- Draw base
            love.graphics.setColor(0.3, 0.3, 0.3, 0.7)
            love.graphics.rectangle('fill', self.target.x - HEX_RADIUS/2, self.target.y - HEX_RADIUS/2, 
                HEX_RADIUS, HEX_RADIUS)
    
            -- Draw spikes
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
            local spike_count = 4
            local spike_height = 12
            local base_width = 8
            
            for i = 1, spike_count do
                for j = 1, spike_count do
                    local sx = math.ceil(self.target.x - HEX_RADIUS/3 + (i-1) * HEX_RADIUS/(spike_count) - 2)
                    local sy = math.ceil(self.target.y - HEX_RADIUS/3 + (j-1) * HEX_RADIUS/(spike_count) - 2)
                    
                    love.graphics.polygon('fill', 
                        sx - base_width/2, sy + spike_height/2,
                        sx + base_width/2, sy + spike_height/2,
                        sx, sy - spike_height/2
                    )
                end
            end
    
            -- Draw warning marks
            love.graphics.setColor(0.8, 0.2, 0.2, 0.5)
            love.graphics.rectangle('line', self.target.x - HEX_RADIUS/2, self.target.y - HEX_RADIUS/2, 
                HEX_RADIUS, HEX_RADIUS)
        end
    })
end

function SpikeTrap:update(dt)
    return true
end

function SpikeTrap:draw()
end

return SpikeTrap