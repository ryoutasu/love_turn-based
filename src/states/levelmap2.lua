-- local Characters = require 'src.characters'

local gen = require 'src.levelgenerator'

local offset = 75

local Player = require 'src.player'
local Node = require 'src.levelmap.node'
local CharacterList = require 'src.characterList'

local Path = Class{}

function Path:init(edge)
    self.edge = edge
    self.isOpen = false
end

function Path:draw()
    if self.isOpen then
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
end

function Levelmap:enter(from, args)
    local seed = args.seed or os.time()
    math.randomseed(seed)

    local characterName = args.character
    
    self.nodes = {}
    self.pathes = {}
    self.currentNode = nil

    self.player = Player()
    self.player:addCharacter(characterName)
    self.player:addItem('catcher', 2)
    self.player:addItem('healPotion', 2)
    self.characterList:setup(self.player.party)

    self.generator = gen()
    self.generator:generate(150, love.graphics.getWidth() - offset*2, love.graphics.getHeight() - offset*2)

    for _, edge in ipairs(self.generator.edges) do
        local path = Path(edge)
        table.insert(self.pathes, path)
        edge.path = path
    end

    local restNodes = 0
    local startPoint = self.generator.startPoint
    local endPoint = self.generator.endPoint
    for i, point in ipairs(self.generator.points) do
        local isStartingPoint = point == startPoint
        local isEndingPoint = point == endPoint

        local type = 'wild'
        if isStartingPoint then
            type = 'start'
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
            if not startNeighbor and not endNeighbor and restNodes < 1 then
                type = 'rest'
                restNodes = restNodes + 1
            elseif rand <= 35 then
                type = 'event'
            elseif rand > 35 and rand <= 50 then
                type = 'trainer'
            end
        end
        
        local node = Node(point.x + offset, point.y + offset, isStartingPoint, type)
        node.point = point

        if isStartingPoint then
            self.currentNode = node
        end

        table.insert(self.nodes, node)
    end
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
        if args.complete then
            self.currentNode.isCompleted = true
        else
            self.currentNode.isOpen = true
        end
    elseif from == EventState then
        self.currentNode.isCompleted = true
    else
        self.currentNode.isCompleted = true
    end

    self.currentNode = nil
    
    self.characterList:setup(self.player.party)
end

function Levelmap:openNeighborNodes(node)
    local currentPoint = node.point

    for _, path in ipairs(self.pathes) do
        path.isOpen = false
    end

    for _, other in ipairs(self.nodes) do
        local point = other.point
        local isNeighbors, edge = self.generator:isNeighbors(currentPoint, point)
        if isNeighbors then
            other.isOpen = true
            other.isDiscovered = true
            edge.path.isOpen = true
        else
            other.isOpen = false
        end
    end
end

function Levelmap:update(dt)
    for _, node in ipairs(self.nodes) do
        node:update(dt)
    end
end

function Levelmap:draw()
    for _, path in ipairs(self.pathes) do
        path:draw()
    end
    for _, node in ipairs(self.nodes) do
        node:draw()
    end

    self.characterList:draw()
end

function Levelmap:mousepressed(x, y, button)
    for _, node in ipairs(self.nodes) do
        if node.cursorInside and node.isOpen then
            self.currentNode = node

            if node.isCompleted then
                self:openNeighborNodes(node)
            else
                Gamestate.push(node:getGamestate(), { player = self.player, type = node.type })
            end
        end
    end
end

return Levelmap