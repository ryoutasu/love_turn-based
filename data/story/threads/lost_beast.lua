-- "The beast that leaves" — the genre's moral beat.
--
-- Digimon World is built almost entirely on this: your creature's
-- behaviour is a consequence of how you treated it, and it can walk away.
-- Here it is a single scene with three honest options, none of which is
-- obviously "the correct one":
--
--   * chase  — you get it back, but the whole party pays something;
--   * let go — you lose the creature, and gain essence instead;
--   * stay   — you do nothing; the creature returns on its own terms.
--
-- Crucially the player must have a party large enough that losing one
-- creature is survivable — otherwise the scene would just be a punishment
-- dressed as a choice.

local PlayerMetaStory = require 'src.player_meta_story'
local RunState        = require 'src.states.run_state'

local FLAG = 'lost_beast_done'

local function party_size(player)
    local n = 0
    for _, list in ipairs({ player.charactersActive, player.charactersSpare }) do
        for _, c in ipairs(list or {}) do
            if c then n = n + 1 end
        end
    end
    return n
end

-- The creature most likely to wander: lowest current health ratio.
local function weakest(player)
    local best, best_ratio
    for _, list in ipairs({ player.charactersActive, player.charactersSpare }) do
        for _, c in ipairs(list or {}) do
            if c and c.health and c.max_health and c.max_health > 0 then
                local ratio = c.health / c.max_health
                if not best_ratio or ratio < best_ratio
                   or (ratio == best_ratio and tostring(c.name) < tostring(best.name)) then
                    best, best_ratio = c, ratio
                end
            end
        end
    end
    return best, best_ratio
end

return {
    id   = 'lost_beast',
    type = 'bond',

    requires = function(camp)
        return not camp.completed_threads[FLAG]
    end,

    weight = function(camp)
        return 5
    end,

    build = function(ctx)
        local player = ctx.player
        -- Only offer this when the party can absorb a loss (2+ creatures)
        -- and someone is actually hurt enough to be plausible.
        local _, ratio = weakest(player)
        local n = party_size(player)

        if n < 2 then return nil end
        if not ratio or ratio > 0.6 then return nil end

        return {
            start = {
                scene    = 'lost_beast',
                terminal = true,
            },
        }
    end,

    on_complete = function(camp, thread_state)
        -- Сцена одноразовая (своё условие выхода у неё своё — слабое
        -- существо в отряде); закрываем нить явно.
        PlayerMetaStory.mark_thread_complete(camp, 'lost_beast')
    end,

    on_fail = function(camp, thread_state)
        PlayerMetaStory.set_active_thread(camp, 'lost_beast', {})
    end,

    FLAG = FLAG,
}
