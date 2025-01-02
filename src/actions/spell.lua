local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Spell = Class{}
Spell:include(action)
Spell.name = 'Spell'

---Spell class
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

    actor:add_stat('energy', -spell.cost)

    self.target = target
    self.spell = spell(actor, target)
end

function Spell:start()
    Tagtext:add(self.spell.name, self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function Spell:update(dt)
    local complete = self.spell:update(dt)

    if complete then
        if self.target.set_animation then
            self.target:set_animation()
        end
    end

    return complete
end

function Spell:draw()
    self.spell:draw()
end

return Spell