-- Story scene registry. Every scene referenced by a thread graph must be
-- declared here.
--
-- A scene exposes:
--   id        string
--   slots     { master = true } / { rival = true } — what generate() expects
--   generate(ctx) -> { title = string, steps = { ... } }   (EventState format)
--   is_boss   bool|nil   after this scene, start a battle
--   terminal  bool|nil   this scene ends the thread

return {
    -- master_trial
    master_arrival    = require 'data.story.scenes.master_arrival',
    master_crossroads = require 'data.story.scenes.master_crossroads',
    master_gate       = require 'data.story.scenes.master_gate',
    master_find_key   = require 'data.story.scenes.master_find_key',
    master_boss       = require 'data.story.scenes.master_boss',
    master_boss_angry = require 'data.story.scenes.master_boss_angry',

    -- rival_encounter
    rival_meet        = require 'data.story.scenes.rival_meet',
    rival_duel        = require 'data.story.scenes.rival_duel',

    -- lore_moon_key (two halves, different runs)
    moon_key_find     = require 'data.story.scenes.moon_key_find',
    moon_door_prelude = require 'data.story.scenes.moon_door_prelude',
    moon_door         = require 'data.story.scenes.moon_door',

    -- bond_arc
    bond_creature     = require 'data.story.scenes.bond_creature',

    -- lost_beast
    lost_beast        = require 'data.story.scenes.lost_beast',
}
