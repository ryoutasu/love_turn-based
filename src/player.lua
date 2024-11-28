local Characters = require 'src.characters'
local ItemList = require 'src.items'

local function setupCharacter(name)
    local character_table = Characters[name]
    local result = {}

    for key, value in pairs(character_table) do
        result[key] = value
    end

    if result.health then
        result.current_health = result.health
    end

    return result
end

local Player = Class{}

function Player:init()
    self.party = {}
    self.inventory = {}
end

function Player:addCharacter(name_or_table)
    if type(name_or_table) == 'string' then
        name_or_table = setupCharacter(name_or_table)
    end

    table.insert(self.party, name_or_table)
end

function Player:addItem(itemName, quantity)
    local item = ItemList[itemName]
    for index, inventoryItem in ipairs(self.inventory) do
        if inventoryItem.item.name == item.name then
            inventoryItem.quantity = inventoryItem.quantity + quantity
            return
        end
    end
    table.insert(self.inventory, { item = item, quantity = quantity, isActive = true })
end

function Player:useItem(item, quantity)
    for index, inventoryItem in ipairs(self.inventory) do
        if inventoryItem.item.name == item.name then
            inventoryItem.quantity = inventoryItem.quantity - quantity

            if inventoryItem.quantity <= 0 then
                table.remove(self.inventory, index)
            end
        end
    end
end

return Player