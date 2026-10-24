local Spellcast = Class{}

function Spellcast:init(caster, target, spell)
    if spell.type == 'unit' then
        target = target.actor
    end
    self.caster = caster
    self.target = target

    self.spell = spell

    self.effects = {}

    self.isStarted = false
    self.isCompleted = false
end

function Spellcast:startCast()
    self.isStarted = true
    self.spell.onCast(self, self.caster, self.target)
    
    -- if not self.target or self.target.actor == self.actor then
    --     BattleState:addLog(self.actor.name .. ' casts ' .. self.spellcast.spell.name .. '!')
    -- end
end

function Spellcast:addEffect(effect)
    table.insert(self.effects, effect)
end

function Spellcast:complete()
    self.isCompleted = true
end

function Spellcast:update(dt)
    for index, effect in ipairs(self.effects) do
        effect:update(dt)
    end
end

function Spellcast:draw()
    for index, effect in ipairs(self.effects) do
        effect:draw()
    end
end

return Spellcast