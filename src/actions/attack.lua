local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Attack = Class{}
Attack:include(action)
Attack.name = 'Attack'

local attack_time = 0.25
local back_time = 0.4
function Attack:init(actor, target)
    action.init(self, actor)
    self.target = target
end

function Attack:start()
    local target = self.target
    local actor = self.actor

    self.tween = tween.new(attack_time, actor, { x = target.x, y = target.y }, 'inBack')
    self.attacking = true
    target.tile.can_be_selected = false

    Tagtext:add('Attack', self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function Attack:update(dt)
    local complete = self.tween:update(dt)
    if not complete then return false end

    if self.attacking then
        self.tween = tween.new(back_time, self.actor, { x = self.actor.tile.x, y = self.actor.tile.y + UNIT_ALIVE_OFFSET }, 'outSine')
        self.attacking = false

        -- Промах атакующего — это его miss_chance (штраф от Sand Throw и
        -- подобных эффектов). Раньше бралось поле `actor.miss_chance`,
        -- которое выставлялось напрямую в обход Stats, поэтому апгрейды
        -- на miss_chance не влияли ни на что.
        local miss = self.actor:get_stat('miss_chance') or 0
        miss = math.min(math.max(miss, 0), 0.75)

        if math.random() > miss then
            -- Броня применяется только к физической атаке: is_attack = true.
            self.target:take_damage(self.actor, self.actor.damage, true)
        else
            Tagtext:add('Miss!', self.target.x + 5, self.target.y - 40, 2, 30, { 1, 0, 0 })
            BattleState:addLog(self.actor.name .. ' miss an attack')
        end

        PlaySound(BoopSound)

    else
        self.target.tile:set_animation()
        return true
    end

    return false
end

return Attack