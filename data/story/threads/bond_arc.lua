-- Creature bond thread.
--
-- The genre's most distinctive narrative device is not the rival — it is
-- that the creatures have relationships with you. Digimon (care, evolution
-- gated by how you treated it), Yo-kai Watch (friendship), Palworld
-- (keeping them fed and safe) all build story out of the creature's
-- response to the player's behaviour.
--
-- Mechanisation: pick the creature the player has used the most
-- (by level, then by health lost, then alphabetically for determinism),
-- and let it speak. Two branches:
--   * trust it  — a run-scoped buff for that creature (and a memory flag);
--   * test it   — a risk: either a bigger buff or a curse, decided by RNG.
--
-- The point is that the choice is about the creature, not about numbers:
-- both outcomes are survivable, neither is strictly better.

local PlayerMetaStory = require 'src.player_meta_story'

local ARC_FLAG = 'bond_arc_done'

local function all_characters(player)
    local out = {}
    for _, list in ipairs({
        player.charactersActive,
        player.charactersSpare,
        player.charactersStables,
    }) do
        for _, c in ipairs(list or {}) do
            out[#out + 1] = c
        end
    end
    return out
end

-- Most-invested creature, deterministic tie-break by name.
local function pick_companion(player)
    local best
    for _, c in ipairs(all_characters(player)) do
        if c and c.name then
            if not best then
                best = c
            else
                local better =
                    (c.level or 1) > (best.level or 1)
                    or ((c.level or 1) == (best.level or 1)
                        and (c.exp or 0) > (best.exp or 0))
                    or ((c.level or 1) == (best.level or 1)
                        and (c.exp or 0) == (best.exp or 0)
                        and tostring(c.name) < tostring(best.name))
                if better then best = c end
            end
        end
    end
    return best
end

return {
    id   = 'bond_arc',
    type = 'bond',

    requires = function(camp)
        -- Одноразовая нить: одна арка привязанности на кампанию.
        return not camp.completed_threads['bond_arc']
    end,

    weight = function(camp)
        -- Бонд требует истории, но не должен голодать: как только забегов
        -- достаточно, вес конкурентоспособен с lore-нитью.
        if (camp.total_runs or 0) < 1 then return 0 end
        return 8
    end,

    build = function(ctx)
        return {
            start = {
                scene    = 'bond_creature',
                terminal = true,
            },
        }
    end,

    on_complete = function(camp, thread_state)
        -- Одноразовая нить: помечаем completed_threads, иначе она будет
        -- повторяться каждый забег бесконечно (своего условия выхода нет).
        PlayerMetaStory.mark_thread_complete(camp, 'bond_arc')
    end,

    on_fail = function(camp, thread_state)
        -- Поражение не отменяет арку: сцена так и не была сыграна.
        PlayerMetaStory.set_active_thread(camp, 'bond_arc', {})
    end,

    -- Exposed for scenes and tests.
    pick_companion = pick_companion,
}
