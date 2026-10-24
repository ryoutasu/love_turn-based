local Item = require 'src.item'
local action = require 'src.actions.action'
local tween = require 'lib.tween'

local ItemAction = Class{}
ItemAction:include(action)
ItemAction.name = 'Item'

---Spell class
---@param caster table
---@param item table
---@param target table tile
function ItemAction:init(caster, item, target)
    action.init(self, caster)

    self.target = target
    -- self.item = item(caster, target)
    self.item = Item(item, caster, target)

    caster:removeItem(item, 1)
end

function ItemAction:start()
    -- Tagtext:add(self.item.name, self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function ItemAction:update(dt)
    local complete = self.item:update(dt)

    if complete then
        if self.target.set_animation then
            self.target:set_animation()
        end
    end

    return complete
end

function ItemAction:draw()
    self.item:draw()
end

return ItemAction