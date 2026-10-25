local MasterGenerator = require 'data.story.generators.master_generator'
local RunState = require 'src.states.run_state'

return {
    id    = 'master_boss_angry',
    slots = { master = true },
    generate = function(ctx)
        local m = ctx.master
        local line = MasterGenerator.line_for(m, ctx.campaign, 'greeting')
        return {
            title = m.dojo_name .. " (enraged)",
            steps = {
                {
                    text = function()
                        return (("You arrive at the %s without the key. "
                             .. "The master does not step back.\n\n"
                             .. "\"%s\"\n\n"
                             .. "Their eyes are not the eyes of a teacher."):format(m.dojo_name, line))
                    end,
                    buttons = {
                        { text = "Stand your ground.", action = function(player)
                            -- Signal to levelmap: boss battle is enraged.
                            RunState.story.flags.boss_enraged = true
                            return 0
                        end },
                    },
                },
            },
        }
    end,
}