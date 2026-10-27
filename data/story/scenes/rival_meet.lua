-- First / middle / final meeting with the rival — the dialogue half.
-- The duel itself is rival_duel.lua; this scene branches on stage.

local RivalGenerator = require 'data.story.generators.rival_generator'
local RunState = require 'src.states.run_state'

return {
    id = 'rival_meet',
    slots = { rival = true, master = false },

    generate = function(ctx)
        local rival = ctx.rival
        local camp  = ctx.campaign
        local stage = RivalGenerator.stage(rival)

        local title
        local text
        local buttons

        if stage == 1 then
            -- First meeting: they took the creature you did not take.
            -- This is the genre's founding beat, and it is personal.
            title = "A familiar road"
            text = function()
                local line = RivalGenerator.line_for(rival, 'first_meet')
                return ("Someone is already at the fork in the road, shifting "
                     .. "from foot to foot. Beside them — a %s, just out of "
                     .. "its shell, still unsure of its own claws.\n\n"
                     .. "\"%s\"\n\n"
                     .. "They say their name. %s. You will hear it again.")
                    :format(rival.starter or 'small beast', line, rival.name)
            end
            buttons = {
                {
                    text = "Offer your hand.",
                    action = function(player)
                        RunState:addUnlock('rival_friendly')
                        RivalGenerator.record(camp, nil)   -- not a win/loss
                        rival.met_in_run = camp.total_runs
                        rival.meetings = 1
                        return 0
                    end,
                },
                {
                    text = "Say nothing. Walk on.",
                    action = function(player)
                        RunState:addUnlock('rival_cold')
                        RivalGenerator.record(camp, nil)
                        rival.met_in_run = camp.total_runs
                        rival.meetings = 1
                        return 0
                    end,
                },
            }

        elseif stage == 2 then
            title = "The same inn"
            text = function()
                local line = RivalGenerator.line_for(rival, 'second_meet')
                local record = ""
                if (rival.wins or 0) > 0 and (rival.losses or 0) == 0 then
                    record = "\n\nThey have won before. They are very aware of it."
                elseif (rival.losses or 0) > 0 and (rival.wins or 0) == 0 then
                    record = "\n\nThey have not forgotten the last time."
                elseif (rival.wins or 0) > 0 then
                    record = "\n\nYou are even. Neither of you says it."
                end
                return ("A fire, a lean-to, and someone already sitting by it. "
                     .. "The %s is bigger now. So is theirs.\n\n"
                     .. "\"%s\"%s"):format(rival.starter or 'beast', line, record)
            end
            buttons = {
                {
                    text = "\"Again, then.\"",
                    action = function(player)
                        RunState:addUnlock('rival_rematch')
                        -- Каждая встреча сдвигает счётчик: иначе stage
                        -- навсегда остаётся 2 и соперник не растёт.
                        RivalGenerator.record(camp, nil)
                        rival.met_in_run = camp.total_runs
                        return 0
                    end,
                },
            }

        else
            title = "The last road"
            text = function()
                local line = RivalGenerator.line_for(rival, 'taunt')
                local history = ""
                if (rival.losses or 0) > (rival.wins or 0) then
                    history = "\n\nThey have been behind you this whole time. "
                           .. "They say it does not matter."
                elseif (rival.wins or 0) > (rival.losses or 0) then
                    history = "\n\nThey have beaten you more often than not. "
                           .. "They are trying not to smile."
                else
                    history = "\n\nEven. Truly even. Of course it would come to this."
                end
                return ("The road narrows into stone and the stone narrows into "
                     .. "a gate. They are sitting on it, waiting, as if they "
                     .. "have been here for hours.\n\n"
                     .. "\"%s\"%s"):format(line, history)
            end
            buttons = {
                {
                    text = "\"One more.\"",
                    action = function(player)
                        RunState:addUnlock('rival_final')
                        -- Финальная встреча тоже считается: она закрывает
                        -- арку и больше не повторяется.
                        RivalGenerator.record(camp, nil)
                        rival.met_in_run = camp.total_runs
                        return 0
                    end,
                },
                {
                    text = "\"Let it be.\"",
                    action = function(player)
                        -- Walking away is a valid ending for this rivalry:
                        -- it leaves the relationship unresolved, which is
                        -- more interesting than a tidy win. Still counts as
                        -- the final meeting so the thread closes.
                        RunState:addUnlock('rival_walked_away')
                        RivalGenerator.record(camp, nil)
                        rival.met_in_run = camp.total_runs
                        return 0
                    end,
                },
            }
        end

        return {
            title = title,
            steps = {
                {
                    text   = text,
                    buttons = buttons,
                },
            },
        }
    end,
}
