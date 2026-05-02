  ---
  Prompt — Plan A (Foundation)

  Execute plan at docs/superpowers/plans/2026-05-02-pokidle-plan-a-foundation.md
  in repo /home/pab/repos/dump/playground/bASH.

  Use the superpowers:subagent-driven-development skill: dispatch one fresh subagent
  per task, run two-stage review between tasks. Tasks use checkbox syntax — mark each
  complete as you go.

  Spec for context: docs/superpowers/specs/2026-05-02-pokidle-design.md

  Note: lib/api.bash and pokeapi.bash have uncommitted changes from a prior session
  (natures endpoint added). Either commit them first as a separate commit, or fold
  them into Plan A Task 3 (the pokeapi rename) — your call.

  Stop after Task 14 (foundation smoke). Plans B and C will run in separate sessions.

  ---
  Prompt — Plan B (Encounter engine + Notifications + CLI)

  Execute plan at docs/superpowers/plans/2026-05-02-pokidle-plan-b-engine-cli.md
  in repo /home/pab/repos/dump/playground/bASH.

  Prerequisite: Plan A must be complete (foundation libs, schema, biomes config,
  pokeapi rename, http rate-limit). Verify before starting:
    - bats tests/ passes
    - lib/db.bash, lib/biome.bash, schema.sql, config/biomes.json all exist
    - pokeapi (no .bash) is the executable name

  Use the superpowers:subagent-driven-development skill: dispatch one fresh subagent
  per task, run two-stage review between tasks.

  Spec for context: docs/superpowers/specs/2026-05-02-pokidle-design.md

  Stop after Task 20 (full Plan B suite green). Plan C runs in a separate session.

  ---
  Prompt — Plan C (Daemon + systemd + Setup)

  Execute plan at docs/superpowers/plans/2026-05-02-pokidle-plan-c-daemon-systemd.md
  in repo /home/pab/repos/dump/playground/bASH.

  Prerequisite: Plans A and B must be complete. Verify before starting:
    - bats tests/ passes (all Plan A + Plan B suites)
    - pokidle entry script + lib/encounter.bash + lib/notify.bash + lib/showdown.bash exist
    - pokidle tick / list / items / stats / current / rebuild-pool / rebuild-biomes / clean
      subcommands work
    - daemon / setup / uninstall / status are still stubs

  Use the superpowers:subagent-driven-development skill: dispatch one fresh subagent
  per task, run two-stage review between tasks.

  Spec for context: docs/superpowers/specs/2026-05-02-pokidle-design.md

  Task 4 (sound assets) requires sourcing royalty-free OGG files — if you cannot
  redistribute them, leave share/sounds/README.md instead per the plan's fallback
  note.

  Final step (Task 7) does live-API integration; allow ~10 minutes for
  `pokidle rebuild-biomes`.
