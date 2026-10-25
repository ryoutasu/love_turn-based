local MasterGenerator = require 'data.story.generators.master_generator'
local RunState = require 'src.states.run_state'

return {
    id    = 'master_boss',
    slots = { master = true },
    generate = function(ctx)
        local m = ctx.master
        local greeting = MasterGenerator.line_for(m, ctx.campaign, 'greeting')
        return {
            title = m.dojo_name,
            steps = {
                {
                    text = function()
                        return (("%s, %s of the %s, steps forward. \"%s\"")
                            :format(m.title, m.name, m.dojo_name, greeting))
                    end,
                    buttons = {
                        { text = "Ready yourself.", action = function(player)
                            RunState.story.flags.boss_intro_done = true
                            return 0
                        end },
                    },
                },
            },
        }
    end,
}