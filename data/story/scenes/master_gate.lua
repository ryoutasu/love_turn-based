return {
    id    = 'master_gate',
    slots = { master = true },
    generate = function(ctx)
        local m = ctx.master
        return {
            title = "The gate",
            steps = {
                {
                    text = function()
                        return ("The gate of the %s looms above you. Old iron, "
                             .. "older bindings. In its centre: a lock shaped like a snake. "
                             .. "You have no key. The lock does not care."):format(m.dojo_name)
                    end,
                    buttons = {
                        { text = "Move on.", action = function() return 0 end },
                    },
                },
            },
        }
    end,
}