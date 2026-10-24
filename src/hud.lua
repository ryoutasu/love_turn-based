local HUD = {}

function HUD:draw()
    -- local player = Gamestate.getCurrentPlayer()
    local player
    for index, state in ipairs(Gamestate.stack) do
        if state.player then player = state.player; break; end
    end
    if not player then return end

    player:drawCurrency()

    -- if Levelmap:isActive() then
    --     player:drawLives()
    -- end

    -- Полный список персонажей — только вне боя
    if not BattleState:isActive() then
        player:drawCharacterList()
    end

    -- Полоска опыта — только на карте и в городе
    if not BattleState:isActive() then
        player:drawExperienceBar()
    end
end

return HUD