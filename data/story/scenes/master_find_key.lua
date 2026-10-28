local RunState = require 'src.states.run_state'

return {
    id    = 'master_find_key',
    slots = { master = true },
    generate = function(ctx)
        local m = ctx.master
        return {
            title = "The altar",
            steps = {
                {
                    text = "The forest opens into a glade. At its centre — a stone altar, "
                        .. "wound around with faded cloth. A key rests on it. It is cold to the touch.",
                    buttons = {
                        { text = "Take the key.", action = function(player)
                            RunState:addUnlock('dojo_key')
                            Tagtext:add("Dojo key acquired.",
                                love.mouse.getX(), love.mouse.getY(),
                                1, 30, { 1, 1, 1 })
                            return 0
                        end },
                        { text = "Leave it.", action = function() return 0 end },
                    },
                },
            },
        }
    end,
}