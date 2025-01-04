-- local Characters = require 'src.characters'

local gen = require 'src.levelgenerator'

local offset = 75

local Inventory = require 'src.levelmap.inventory'
local Player = require 'src.player'
local Node = require 'src.levelmap.node'
local CharacterList = require 'src.characterList'

local Item = require 'src.actions.item'

local fontSize = 14
local font = love.graphics.newFont(fontSize)

local Path = Class{}

function Path:init(edge)
    self.edge = edge
    self.isOpen = false
    self.isCompleted = false
end

function Path:draw()
    if self.isCompleted then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
    elseif self.isOpen then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0, 0, 0, 1)
    end
    local edge = self.edge
    love.graphics.line(edge.p1.x + offset, edge.p1.y + offset, edge.p2.x + offset, edge.p2.y + offset)
end

local Levelmap = Class{}

function Levelmap:init()
    self.nodes = {}
    self.pathes = {}
    self.currentNode = nil
    self.characterList = CharacterList(10, 10)
    self.inventory = Inventory(100, 10)
end

function Levelmap:enter(from, args)
    local seed = args.seed or os.time()
    math.randomseed(seed)

    local characterName = args.character
    
    self.nodes = {}
    self.pathes = {}
    self.currentNode = nil

    self.player = Player()
    self.player:addCharacter(characterName, true)
    self.player:addItem('catcher', 1)
    self.player:addItem('healPotion', 2)
    self.player:addItem('energyPotion', 2)
    self.player:addCurrency('gold', 100)
    self.characterList:setup(self.player.party)
    self.inventory:setup(self.player.inventory)

    self.generator = gen()
    self.generator:generate(150, love.graphics.getWidth() - offset*2, love.graphics.getHeight() - offset*2)

    for _, edge in ipairs(self.generator.edges) do
        local path = Path(edge)
        table.insert(self.pathes, path)
        edge.path = path
    end

    local startPoint = self.generator.startPoint
    local endPoint = self.generator.endPoint
    local rest_nodes = 0
    local shop_nodes = 0

    local max_event_nodes = math.floor(#self.generator.points * 0.30)
    local event_nodes = 0

    local max_trainer_nodes = math.floor(#self.generator.points * 0.35)
    local trainer_nodes = 0

    for i, point in ipairs(self.generator.points) do
        local isStartingPoint = point == startPoint
        local isEndingPoint = point == endPoint

        local type = 'wild'
        if isStartingPoint then
            type = 'wild'
        elseif isEndingPoint then
            type = 'end'
        else
            -- decide node type:
            -- if a point not next to the start nor the end, it can be rest or event
            -- can be only 1 rest point per level
            -- other than start, end and rest nodes:
            -- 35% fight:
            -- 20% wild
            -- 15% trainer
            -- 35% event
            -- 30% elites
            local startNeighbor = self.generator:isNeighbors(point, startPoint)
            local endNeighbor = self.generator:isNeighbors(point, endPoint)
            local rand = math.random() * 100
            if not startNeighbor and not endNeighbor and rest_nodes < 1 then
                type = 'rest'
                rest_nodes = rest_nodes + 1
            elseif not startNeighbor and not endNeighbor and shop_nodes < 1 then
                type = 'shop'
                shop_nodes = shop_nodes + 1
            elseif rand <= 35 and event_nodes < max_event_nodes then
                type = 'event'
                event_nodes = event_nodes + 1
            elseif rand <= 65 and trainer_nodes < max_trainer_nodes then
                type = 'trainer'
                trainer_nodes = trainer_nodes + 1
            end
        end
        
        local node = Node(point.x + offset, point.y + offset, isStartingPoint, type)
        node.point = point

        if isStartingPoint then
            self.currentNode = node
        end

        table.insert(self.nodes, node)
    end

    self.currentSpell = nil
    self.mode = 'none'
    self.currentAction = nil
end

function Levelmap:resume(from, args)
    self:openNeighborNodes(self.currentNode)
    
    if from == BattleState then
        if args.result == 'lose' then
            Gamestate.pop()
        else
            self.currentNode.isCompleted = true
        end
    elseif from == RestState then
        -- if args.complete then
            self.currentNode.isCompleted = true
        -- else
        --     self.currentNode.isOpen = true
        -- end
    elseif from == ShopState then
        self.currentNode.isCompleted = true
        -- self.currentNode.isOpen = true
    elseif from == EventState then
        self.currentNode.isCompleted = true
    else
        self.currentNode.isCompleted = true
    end

    self.currentNode = nil
    
    self.characterList:setup(self.player.party)
    self.inventory:setup(self.player.inventory)

    self:cancel_target_mode()
end

function Levelmap:openNeighborNodes(node)
    local currentPoint = node.point

    -- for _, path in ipairs(self.pathes) do
    --     path.isOpen = false
    -- end

    for _, other in ipairs(self.nodes) do
        local point = other.point
        local isNeighbors, edge = self.generator:isNeighbors(currentPoint, point)
        -- if isNeighbors then
        --     other.isOpen = true
        --     other.isDiscovered = true
        --     edge.path.isOpen = true
        -- else
        --     other.isOpen = false
        -- end
        if isNeighbors then
            if not other.isCompleted then
                other.isOpen = true
                other.isDiscovered = true
                edge.path.isOpen = true
            end
        end
    end
    node.isOpen = false
end

function Levelmap:set_target_mode(spell)
    self.mode = 'target'
    self.currentSpell = spell
    self.characterList.showBox = true
end

function Levelmap:cancel_target_mode()
    self.mode = 'none'
    self.currentSpell = nil
    self.characterList.showBox = false
end

function Levelmap:update(dt)
    for _, node in ipairs(self.nodes) do
        node:update(dt)
    end
    self.characterList:update(dt)
    self.inventory:update(dt)
end

function Levelmap:draw_currencies()
    local padding = 4
    local w, h = self.inventory.w, self.inventory.h
    local x, y = self.inventory.x + w + 10, self.inventory.y
    for name, value in pairs(self.player.currencies) do
        local text = name .. ': ' .. tostring(value)
        local textW = font:getWidth(text) + padding + padding
        local textH = font:getHeight(text) + padding + padding
    
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, textW, textH)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', x, y, textW, textH)

        love.graphics.setFont(font)
        love.graphics.setColor(0, 0, 0, 1)
        PrintText(text, x + padding, y + padding)

        x = x + textW + 10
    end

    return x, y
end

function Levelmap:draw()
    for _, path in ipairs(self.pathes) do
        path:draw()
    end
    for _, node in ipairs(self.nodes) do
        node:draw()
    end

    self.characterList:draw()
    self.inventory:draw()

    local padding = 4
    local x, y = self:draw_currencies()
    
    if self.currentSpell then
        local text = 'Casting: ' .. self.currentSpell.name
        local textW = font:getWidth(text)
        local textH = font:getHeight(text)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, textW + padding + padding, textH + padding + padding)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', x, y, textW + padding + padding, textH + padding + padding)

        love.graphics.setFont(font)
        PrintText(text, x + padding, y + padding)
    end
end

function Levelmap:mousepressed(x, y, button)
    for _, node in ipairs(self.nodes) do
        if node.cursorInside then
            if node.isOpen then
                self.currentNode = node
    
                if node.isCompleted then
                    -- self:openNeighborNodes(node)
                else
                    Gamestate.push(node:getGamestate(), { player = self.player, type = node.type })
                end
    
                PlaySound(ButtonClickSound)
            else
                PlaySound(ErrorSound, 0.4)
            end
        end
    end

    if self.mode == 'target' and self.characterList.highlighted and self.currentSpell then
        -- self.currentAction = 
        Item(self.player, self.currentSpell, self.characterList.highlighted)
        self:cancel_target_mode()
    end

    self.inventory:mousepressed()
end

function Levelmap:keypressed(key)
    if key == 'escape' then
        self:cancel_target_mode()
    end
end

return Levelmap