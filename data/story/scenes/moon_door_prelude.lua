-- Payoff half, part 1: the approach. Explains why the door matters
-- before the player decides. Carries no state itself.

local PlayerMetaStory = require 'src.player_meta_story'

local KEY = 'moon_key'

return {
    id = 'moon_door_prelude',
    slots = {},

    generate = function(ctx)
        local camp = ctx.campaign
        local has_key = PlayerMetaStory.has_story_key(camp, KEY)

        local text
        if has_key then
            text = "The path ends at a door standing alone in the open, with no "
                .. "wall around it. Pale wood, older than the road. In its centre, "
                .. "a lock shaped like a crescent.\n\n"
                .. "The key in your pack is exactly that shape. You have carried "
                .. "it since before this road."
        else
            text = "The path ends at a door standing alone in the open, with no "
                .. "wall around it. Pale wood, older than the road. In its centre, "
                .. "a lock shaped like a crescent — and empty."
        end

        return {
            title = "A door in the open",
            steps = {
                {
                    text = text,
                    buttons = {
                        { text = "Go closer.", action = function() return 0 end },
                    },
                },
            },
        }
    end,
}
