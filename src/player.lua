local Characters = require 'src.characters'
local ItemList = require 'src.items'

local function setupCharacter(name)
    local character_table = Characters[name]
    local character = {}

    for key, value in pairs(character_table) do
        character[key] = value
    end

    if character.max_health then
        character.health = character.max_health
    end

    return character
end

local Player = Class{}

function Player:init()
    self.party = {}
    self.inventory = {}
    self.currencies = {}

    self.characters = {}

    self.main_character = nil
end

function Player:addCharacter(name_or_table, add_to_party)
    if type(name_or_table) == 'string' then
        name_or_table = setupCharacter(name_or_table)
    end

    -- table.insert(self.characters, name_or_table)

    -- if add_to_party then
        table.insert(self.party, name_or_table)
    -- end

    return name_or_table
end

function Player:addCharacterToParty(character_table)
    table.insert(self.party, character_table)
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

function Player:addCurrency(name, value)
    local currency = self.currencies[name]
    if not currency then self.currencies[name] = 0; currency = 0 end
    self.currencies[name] = math.max(currency + value, 0)
end

return Player