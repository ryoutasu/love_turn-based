local action = require 'src.actions.action'
local tween = require 'lib.tween'

local RunState = require 'src.states.run_state'
local Spellcast = require 'src.spellcast.spellcast'

---Spell class
local Spell = Class{}
Spell:include(action)
Spell.name = 'Spell'

---@param actor table actor
---@param spell table spell
---@param target table tile
function Spell:init(actor, spell, target)
    action.init(self, actor)

    if actor.energy < spell.cost then
        print(actor.energy, spell.cost)
        self.is_aborted = true
        return false
    end

    actor:change_energy(-spell.cost)

    self.target = target
    self.spell = spell
    self.spellcast = Spellcast(actor, target, spell)

    if spell.cooldown then
        spell.current_cooldown = spell.cooldown + 1
    end

    if not spell.expirience then
        spell.expirience = 0
    end
    spell.expirience = spell.expirience + 1
end

local anim_time = 0.4
local jump_height = 25

function Spell:start()
    Tagtext:add(self.spell.name, self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })

    self.tween = tween.new(anim_time, self.actor, { z = jump_height }, 'outQuad')
    self.jumping = true
end

function Spell:update(dt)
    local complete

    if self.tween then
        complete = self.tween:update(dt)
        if not complete then return false end

        if self.jumping then
            self.jumping = false
            self.tween = tween.new(anim_time, self.actor, { z = 0 }, 'inQuad')
            return false
        end

        self.tween = nil
    end
    
    if not self.spellcast.isStarted then
        self.spellcast:startCast()
    end
    -- if not self.spellcast then
    --     self.spellcast = Spellcast(self.actor, self.target, self.spell)

    --     if not self.target or self.target.actor == self.actor then
    --         BattleState:addLog(self.actor.name .. ' casts ' .. self.spellcast.spell.name .. '!')
    --     -- else
    --     --     BattleState:addLog(self.actor.name .. ' cast ' .. cast.name .. ' on ' .. self.target.actor.name)
    --     end
    -- end

    self.spellcast:update(dt)
    complete = self.spellcast.isCompleted
    
    RunState:fireHook('on_spell_hit', self.target, self)

    if complete then
        if self.target.set_animation then
            self.target:set_animation()
        end
    end

    return complete
end

function Spell:draw()
    if self.spellcast then
        self.spellcast:draw()
    end
end

return Spell