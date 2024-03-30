local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Spell = Class{}

---Spell class
---@param actor table
---@param spell table
---@param target table tile
function Spell:init(actor, spell, target)
    action.init(self, actor)

    self.target = target
    self.spell = spell(actor, target)
    
    Tagtext:add(spell.name, self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function Spell:update(dt)
    local complete = self.spell:update(dt)

    if complete then
        self.target:set_animation()
    end

    return complete
end

function Spell:draw()
    self.spell:draw()
end

return Spell