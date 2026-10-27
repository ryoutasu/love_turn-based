-- The duel itself. Marks the node as a battle and hands the party
-- descriptors to the battle setup (same shape masters use).

local RivalGenerator = require 'data.story.generators.rival_generator'
local RunState = require 'src.states.run_state'

return {
    id = 'rival_duel',
    slots = { rival = true, master = false },

    -- Signals to levelmap/node: after this scene, start a BattleState.
    is_boss = true,
    terminal = true,

    generate = function(ctx)
        local rival = ctx.rival
        local stage = RivalGenerator.stage(rival)
        local tier  = RivalGenerator.tier(rival)

        -- Store everything the battle needs on RunState so it survives the
        -- transition into BattleState (scenes are stateless).
        RunState.story = RunState.story or {}
        RunState.story.flags = RunState.story.flags or {}
        RunState.story.flags.rival_duel = {
            rival_id  = rival.id,
            stage     = stage,
            tier      = tier,
            party     = RivalGenerator.build_party(rival),
            element   = rival.element,
            attribute = rival.attribute,
            name      = rival.name,
            walked_away = RunState:hasUnlock('rival_walked_away') and true or false,
        }

        local title = (stage >= 3) and "The last duel" or "The duel"

        local text
        if stage >= 3 then
            text = ("No more talking. The %s steps forward — their ace, the "
                 .. "one they have raised since that first fork in the road."
                 .. "\n\nTheir party is %d strong. Yours is what it is.")
                 :format(rival.ace_species or 'beast', tier)
        else
            text = ("\"Then let's settle it.\" The %s is already moving."
                 .. "\n\nTheir party is %d strong.")
                 :format(rival.ace_species or 'beast', tier)
        end

        return {
            title = title,
            steps = {
                {
                    text = text,
                    buttons = {
                        {
                            text = "Fight.",
                            action = function(player)
                                RunState.story.flags.rival_duel.begin = true
                                return 0
                            end,
                        },
                    },
                },
            },
        }
    end,
}
