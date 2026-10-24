local PenCreature = Class{}

PenCreature.SCALE = 0.6

function PenCreature:init(character, x, y, bounds)
    self.character  = character
    self.x          = x
    self.y          = y
    self.bounds     = bounds
    self.state      = 'idle'
    self.idle_timer = math.random() * 3
    self.target_x   = x
    self.target_y   = y
    self.bob_phase  = math.random() * math.pi * 2
    self.dragged    = false
    self.hover      = false
    self.facing     = math.random() < 0.5 and 1 or -1
end

function PenCreature:getSize()
    local sprite = self.character.sprite
    return sprite.w * PenCreature.SCALE, sprite.h * PenCreature.SCALE
end

function PenCreature:getBounds()
    local w, h = self:getSize()
    return self.x - w/2, self.y - h/2, w, h
end

function PenCreature:contains(mx, my)
    local bx, by, bw, bh = self:getBounds()
    return mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
end

function PenCreature:update(dt)
    self.bob_phase = self.bob_phase + dt * 2.5

    if self.dragged then return end

    if self.state == 'idle' then
        self.idle_timer = self.idle_timer - dt
        if self.idle_timer <= 0 then
            self.state    = 'wander'
            self.target_x = self.bounds.x + math.random() * self.bounds.w
            self.target_y = self.bounds.y + math.random() * self.bounds.h
        end
    elseif self.state == 'wander' then
        local dx = self.target_x - self.x
        local dy = self.target_y - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 4 then
            self.state      = 'idle'
            self.idle_timer = 1 + math.random() * 4
        else
            local speed = 35
            self.x = self.x + (dx / dist) * speed * dt
            self.y = self.y + (dy / dist) * speed * dt

            -- Поворот по направлению движения
            if dx > 0.5 then self.facing = 1
            elseif dx < -0.5 then self.facing = -1 end
        end
    end
end

function PenCreature:draw()
    local bob = self.dragged and 0 or (math.sin(self.bob_phase) * 2)
    local sprite = self.character.sprite
    local w, h   = self:getSize()
    local tx     = self.x - w / 2
    local ty     = self.y - h / 2 + bob

    -- Тень (не рисуем при drag, чтобы не висела в воздухе)
    if not self.dragged then
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.ellipse('fill', self.x, self.y + h / 2 - 4, w * 0.35, 5)
    end

    -- Спрайт с учётом facing
    love.graphics.setColor(1, 1, 1, 1)
    local sx  = self.facing * PenCreature.SCALE
    local dx  = (self.facing == -1) and (tx + w) or tx
    sprite:draw(self.character.quad, dx, ty, 0, sx, PenCreature.SCALE)

    -- Hover-рамка
    if self.hover and not self.dragged then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', tx - 2, ty - 2, w + 4, h + 4, 4, 4)
    end
end

return PenCreature