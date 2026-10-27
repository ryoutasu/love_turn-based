-- Story thread registry. Add new threads here.
--
-- Each thread must expose:
--   id          string
--   requires(camp) -> bool           may this thread be selected?
--   weight(camp)   -> number         priority when several are eligible
--   build(ctx)     -> scene_graph    see src/story/scene_graph.lua
--   on_complete(camp, thread_state)  optional
--   on_fail(camp, thread_state)      optional
--
-- NOTE: scenes referenced by a graph live in data/story/scenes.lua.
-- `lua tests/test_story.lua` validates every graph, so a typo in a scene
-- id or a dangling `next` fails there instead of mid-run.

return {
    master_trial    = require 'data.story.threads.master_trial',
    rival_encounter = require 'data.story.threads.rival_encounter',
    lore_moon_key   = require 'data.story.threads.lore_moon_key',
    bond_arc        = require 'data.story.threads.bond_arc',
    lost_beast      = require 'data.story.threads.lost_beast',
}
