local RunState = require 'src.states.run_state'

return {
    id    = 'master_crossroads',
    slots = { master = true },
    generate = function(ctx)
        local m = ctx.master
        return {
            title = "The fork",
            steps = {
                {
                    text = function()
                        return ("The path to the %s splits here. "
                             .. "To the east, a short road — paved, guarded, gated. "
                             .. "To the west, a forest trail. They say it takes longer. "
                             .. "They also say it gives."):format(m.dojo_name)
                    end,
                    buttons = {
                        { text = "Take the short road.", action = function(player)
                            RunState:addUnlock('path_shortcut')
                            return 0
                        end },
                        { text = "Take the forest trail.", action = function(player)
                            RunState:addUnlock('path_scenic')
                            return 0
                        end },
                    },
                },
            },
        }
    end,
}