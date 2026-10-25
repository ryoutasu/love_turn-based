return {
    id    = 'master_arrival',
    slots = { master = true },
    generate = function(ctx)
        local m = ctx.master
        local memory = ctx.campaign.masters[m.id]

        local text
        if memory and memory.defeats > 0 then
            text = ("The road to the %s is familiar now. You have walked it before — "
                 .. "and turned back. The wind carries the same dust."):format(m.dojo_name)
        else
            text = ("Word travels slowly, but it travels. They say the master of the %s "
                 .. "is waiting. Not for you — but for someone. Perhaps that is enough."):format(m.dojo_name)
        end

        return {
            title = m.dojo_name,
            steps = {
                {
                    text = function() return text end,
                    buttons = {
                        { text = "Walk on.", action = function(player)
                            if not ctx.campaign.masters[m.id].first_met_run then
                                ctx.campaign.masters[m.id].first_met_run = ctx.campaign.total_runs
                            end
                            return 0
                        end },
                    },
                },
            },
        }
    end,
}