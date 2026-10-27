# AGENTS.md — Coding rules for AI agents

## Project

**DumbBeasts Adventures** — turn-based tactical roguelike with creature collection.
Stack: LÖVE (Love2D), Lua 5.1 (LuaJIT), custom `Class{}` OOP via metatables.
Saves: `serpent` → `run.sav`. UI: `src/ui.lua` (immediate-mode-like).
Hot reload: `lurker` + `love.event.quit("restart")`.

## Sources of truth (read in this order)

1. `specs.md` — architecture, data model, extension points. **Wins over everything** on conflict.
2. `AGENTS.md` — this file. Coding rules.
3. The 3–5 source files relevant to the task. Nothing more unless needed.

Do not load the whole project into context. Load only what the task requires.

## Non-negotiables

1. **Determinism.** All game-logic randomness goes through `RunState:random()` /
   `RunState:randomInt()`. `math.random` / `love.math.random` is allowed only for
   cosmetic effects (particles, visual jitter), never for gameplay state.
2. **Serialization.** Everything that must survive a save is a table of numbers,
   strings, booleans, or nested tables of those. **No functions, no coroutines,
   no userdata, no LÖVE objects** in serialized state (`Player.meta_story`,
   `RunState.story`, `RunState.modifiers`, etc.). Functions are restored from
   registries by `id` on deserialize.
3. **Modifiers, not direct mutation.** Never write `character.damage = …`.
   Add a modifier: permanent → `Character.addModifier`, run-scope →
   `RunState:addModifier`, battle-scope → `unit.modifiers`. Use `Stats:get()`.
4. **Isolated event modules.** Every event/scene module is
   `return { id = ..., generate = function(ctx) -> steps end }`. No side effects
   at module load time.
5. **All game-facing text is in English.** Comments can be in English too.
   No Russian strings in `data/`, `src/states/`, `src/events/`, `data/story/`.
6. **Don't kill characters outside battle.** Event damage must clamp to
   `math.max(1, hp - dmg)`. `Unit:die` calls battle logic and will break.
7. **`EventState` accepts already-instantiated `steps`.** Do not add generation
   logic inside `EventState`. Generation happens in `scene.generate(ctx)`
   before pushing the state.

## Do not touch without explicit instruction

- `src/states/eventstate.lua` — stable engine, no changes needed
- `src/stats.lua`
- `src/damage_calculator.lua`
- `src/actorQueue.lua`
- `src/events/*.lua` — 12 existing events, wrap them if needed but don't rewrite
- `data/type_chart.lua`

## Key files map

```
data/
  upgrades.lua -- 30+ run upgrades
  story/
    threads.lua -- story thread registry
    threads/master_trial.lua -- main narrative thread
    scenes.lua -- scene registry
    scenes/*.lua -- scene modules
    generators/master_generator.lua

src/
  player.lua -- Player (persistent container)
  player_meta_story.lua -- campaign-level state helper
  character.lua -- Character (persistent)
  stats.lua -- Stats with modifiers
  damage_calculator.lua -- attr × elem × armor
  save_manager.lua -- serialize / deserialize / file I/O

  story/
    thread_generator.lua -- select active thread for a run
    scene_graph.lua -- pure graph ops (BFS, validate)

  states/
    townstate.lua -- hub
    run_state.lua -- run-scope singleton
    levelmap2.lua -- run map + story map generation
    eventstate.lua -- narrative engine (DO NOT TOUCH)
    battlestate.lua -- battle (main)
    upgrade_select_screen.lua
    ...

  objects/
    unit.lua -- battle actor
    
  node.lua -- map node (with story support)
  ui.lua -- UI helpers
  events.lua -- filler event registry
```

## Smoke tests

- Location: `tests/`
- Naming: `tests/smoke_<topic>.lua`
- Must run **headless** where possible. Stub `love.*` calls as needed at the top
  of the test file (e.g. `love = love or { math = { random = math.random } }`).
- Each test: setup → act → assert → `print("smoke_<topic> OK")` → exit 0.
- Prefer plain Lua assertions (`assert(cond, "message")`) over a test framework.
- If the test needs a real `love.run` loop, mark it `tests/visual_<topic>.lua` and
  document how to run it manually.

## Commits

- One task = one commit.
- Conventional Commits: `feat(scope): …`, `fix(scope): …`, `refactor(scope): …`,
  `test(scope): …`, `docs: …`, `chore: …`.
- Never commit `.sav` files, log files, or generated assets.
- `git diff` must be reviewed before committing. Revert if the agent touched
  files outside the task's declared scope.

## Git hygiene

Tracked path is `AGENTS.md` (uppercase). On case-sensitive git (Git Bash on
Windows, WSL, Linux, macOS), `git add -- agents.md` may silently match nothing.
Always use `git add -- AGENTS.md` and verify with `git show --stat HEAD` after
committing.

## Workflow per task

1. **Read** this file, then `specs.md`, then the declared source files.
2. **Plan mode** — propose a plan (files to edit, signatures, test). Do not
   modify files until the plan is approved (`exit_plan_mode`).
3. **Implementation** — Standard mode. Edit only the declared files.
4. **Run** the smoke test from the task. Paste the output.
5. **Report** — list of changed files, diff summary, test result.
6. **Commit** — one commit per task.

## Known issues (do not fix unless the task explicitly asks)

- Placement `is_usable` accepts `{event, wild, trainer}`. Trainer nodes are
  disposable filler (avg 16.46/map, max 20/map) and are the only node type
  needed to reach 100% pinned-sweep placement success. Shop and rest remain
  excluded — they are singletons (1/map) and overwriting them would cost a
  load-bearing resource (upgrade path / only mid-run heal) for zero additional
  seeds. T2/T3/T4 were measured and found strictly worse than T1. See
  `tests/measure_placement` and `tests/measure_placement_tiers` for the data.
- Story scenes are stamped onto `_generateMap`-produced nodes by
  `StoryPlacement`. There is no `_generateStoryMap`, no filler-chain insertion,
  no `_pick_filler_type`. Filler nodes are simply non-stamped nodes.
- Hex map topology: a scene's map neighbours may include the node its parent was
  placed on (grandparent adjacency). **Equal BFS depth for sibling branches is
  NOT guaranteed and is not a valid invariant.** What is guaranteed:
  (1) sibling branches are adjacent to the shared parent (locality of choice),
  (2) at least one arm of a fork is not adjacent to the map start (so the fork
  scene can always be played if the player chooses that route).
  Verify via `smoke_story_placement` (A6', A6''', A6b).
- Bypass: an arm may be adjacent to the map start, allowing the player to skip
  the fork scene (crossroads). The choice is still meaningful (routes differ),
  but the narrative moment can be missed. If narrative enforcement becomes
  required, add a `{ visited_scene = '<scene_id>' }` gate to the arm — currently
  not implemented.
- `scene_graph.validate` treats `alt_when_locked` as a **scene id**, not a graph
  node id. It is NOT a graph edge. A node's `alt_when_locked` field is resolved
  by `Node:resolve_scene_id` via `Scenes[<id>]`, not by walking the graph. Do not
  point `alt_when_locked` at another graph node — collapse the fallback into the
  primary node (see `master_trial.boss`).

## Adjacency

Map adjacency has one authoritative source: `generator:isNeighbors`.
Placement (`StoryPlacement`) and the placement test both use it. Any change to
placement adjacency must update the test in the same commit.

## Determinism

Thread selection is deterministic: same `RunState:reset(seed)` state → same
`ThreadGenerator.select()` outcome. Any addition to a thread's `requires()` or
`weight()` function MUST be a pure function of camp state (no hidden RNG use,
no mutation, no I/O). Any change that breaks this invariant must be caught by
`tests/smoke_thread_determinism.lua`. If you need to debug a selection
discrepancy, run `tests/diagnose_thread_determinism.lua` first — it isolates
direct select vs select-after-generateMap vs select-after-place.

Two traps when writing seeded tests:

- **`select()` is not idempotent across a run.** `_place_story` calls
  `ThreadGenerator.select()` once and pins `camp.active_thread`; a second
  `select()` afterwards returns the *forced continuation*, not a fresh weighted
  pick. `_place_story` also calls `PlayerMetaStory.begin_new_run()`, which bumps
  `camp.total_runs` and can change other threads' weights mid-run. Read the
  thread that actually ran from `levelmap.story.thread.id`.
- **The Park-Miller RNG stub needs warm-up draws.** Its raw first output is
  `(16807*seed mod M - 1)/(M-1)`, which for ordinary seeds is ~1e-5 — a heavy
  bias toward zero. A single-draw weighted pick then always takes the first
  non-zero bucket, which silently fabricates distributions (it is what produced
  the bogus "bond_arc 100/100" sweep). Warm up ~12 draws before exposing
  `newRandomGenerator`.

## Definition of "done"

A task is done when:
- All files in its scope are modified (and only those).
- The declared smoke test passes.
- No new globals leaked (`math.random` not used in game logic, no orphan
  requires).
- A commit exists with a Conventional Commit message.