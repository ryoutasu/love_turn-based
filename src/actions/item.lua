local action = require 'src.actions.action'
local tween = require 'lib.tween'

local Item = Class{}
Item:include(action)
Item.name = 'Item'

---Spell class
---@param player table
---@param item table
---@param target table tile
function Item:init(player, item, target)
    action.init(self, player)

    self.target = target
    self.item = item(player, target)

    player:useItem(item, 1)
end

function Item:start()
    -- Tagtext:add(self.item.name, self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function Item:update(dt)
    local complete = self.item:update(dt)

    if complete then
        self.target:set_animation()
    end

    return complete
end

function Item:draw()
    self.item:draw()
end

return Item