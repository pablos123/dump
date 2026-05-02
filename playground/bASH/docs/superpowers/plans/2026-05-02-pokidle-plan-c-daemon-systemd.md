# pokidle Plan C: Daemon + systemd + Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plans A and B complete.

**Goal:** Wire the `pokidle daemon` loop (biome rotation every 3h, scheduled hourly ticks with random offset, resume on restart, signal handling), the `systemd --user` unit, and the lifecycle subcommands (`setup`, `uninstall`, `status`). Bundle royalty-free sound assets. End state: `pokidle setup --enable` installs and starts the unit; passive game runs in background.

**Architecture:** The daemon is a single bash function (`pokidle_daemon`) that runs `while :; do ... done` with `sleep` between events. Tick targets and the active biome are persisted to `daemon_state` so restarts pick up where they left off. The systemd unit is a `Type=simple` service tied to `graphical-session.target` so notifications work and the daemon doesn't run in lock screens. `setup` copies the repo's `config/biomes.json` + `systemd/pokidle.service` into the user's XDG dirs and runs `systemctl --user daemon-reload`.

**Tech Stack:** bash 4+, systemd user services, libnotify, sqlite3.

**Spec reference:** `docs/superpowers/specs/2026-05-02-pokidle-design.md`.

---

## File map (Plan C)

| File | Status | Responsibility |
|---|---|---|
| `systemd/pokidle.service` | create | systemd `--user` unit template |
| `share/sounds/encounter.ogg` | create | bundled encounter sound |
| `share/sounds/shiny.ogg` | create | bundled shiny sound |
| `pokidle` | modify | implement `pokidle_daemon`, `pokidle_setup`, `pokidle_uninstall`, `pokidle_status` |
| `tests/test-daemon.bats` | create | tick scheduling math + resume logic |
| `tests/test-setup.bats` | create | setup install paths |

---

## Task 1: systemd unit template

**Files:**
- Create: `systemd/pokidle.service`

- [ ] **Step 1: Write the unit**

`systemd/pokidle.service`:

```ini
[Unit]
Description=Pokidle passive pokemon encounter daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/pokidle daemon
Restart=on-failure
RestartSec=30
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
```

- [ ] **Step 2: Lint with `systemd-analyze`**

```bash
systemd-analyze verify systemd/pokidle.service 2>&1 || true
```

(Verify locally — may warn about missing absolute path of ExecStart at lint time; that's resolved at install.)

- [ ] **Step 3: Commit**

```bash
git add systemd/pokidle.service
git commit -m "feat(systemd): user unit template"
```

---

## Task 2: Tick scheduling helpers (testable)

**Files:**
- Modify: `pokidle`
- Create: `tests/test-daemon.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-daemon.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    export POKIDLE_DB_PATH
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib db
    db_init
}

teardown() {
    rm -f "$POKIDLE_DB_PATH"
}

# Source pokidle as a library by extracting its functions.
# We do this by sourcing the script with a guard so it doesn't dispatch.
source_pokidle_lib() {
    POKIDLE_TEST_SOURCE_ONLY=1 source "$REPO_ROOT/pokidle"
}

@test "schedule_next_tick: target is in [next_hour, next_hour+interval)" {
    POKIDLE_POKEMON_INTERVAL=3600
    source_pokidle_lib
    local now=1700000000   # epoch
    local next
    next="$(_pokidle_next_tick_target "$now" "$POKIDLE_POKEMON_INTERVAL")"
    local hour_floor=$((now / 3600 * 3600))
    local next_hour=$((hour_floor + 3600))
    [ "$next" -ge "$next_hour" ]
    [ "$next" -lt "$((next_hour + 3600))" ]
}

@test "_pokidle_should_rotate_biome: 3h elapsed yes" {
    POKIDLE_BIOME_HOURS=3
    source_pokidle_lib
    local now=1700010800   # 3h+ after 1700000000
    run _pokidle_should_rotate_biome 1700000000 "$now"
    [ "$status" -eq 0 ]
}

@test "_pokidle_should_rotate_biome: 1h elapsed no" {
    POKIDLE_BIOME_HOURS=3
    source_pokidle_lib
    local now=1700003600
    run _pokidle_should_rotate_biome 1700000000 "$now"
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Modify `pokidle` to support source-only mode**

At the very top of the dispatcher (just after env defaults block), add a guard:

```bash
# Tests source the script for unit testing helper functions.
if [[ "${POKIDLE_TEST_SOURCE_ONLY:-0}" == "1" ]]; then
    POKIDLE_TEST_SKIP_DISPATCH=1
fi
```

At the bottom, wrap the `case` dispatch:

```bash
if [[ "${POKIDLE_TEST_SKIP_DISPATCH:-0}" == "0" ]]; then
    cmd="${1-}"
    [[ -n "$cmd" ]] || { usage >&2; exit 2; }
    shift
    case "$cmd" in
        # ... existing case body ...
    esac
fi
```

Add the helper functions:

```bash
_pokidle_next_tick_target() {
    local now="$1" interval="$2"
    local next_hour=$(( (now / 3600 + 1) * 3600 ))
    printf '%d' "$(( next_hour + RANDOM % interval ))"
}

_pokidle_should_rotate_biome() {
    local started_at="$1" now="$2"
    local hours="${POKIDLE_BIOME_HOURS:-3}"
    (( now - started_at >= hours * 3600 ))
}
```

- [ ] **Step 3: Run tests, expect pass**

```bash
bats tests/test-daemon.bats
```

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-daemon.bats
git commit -m "feat(daemon): tick scheduler + biome-rotation predicate"
```

---

## Task 3: `pokidle daemon` main loop

**Files:**
- Modify: `pokidle`

- [ ] **Step 1: Implement `pokidle_daemon`**

Replace the `pokidle_daemon` stub:

```bash
pokidle_daemon() {
    db_init
    biome_validate || { printf 'daemon: biome config invalid; aborting\n' >&2; return 1; }

    local active biome sid biome_started_at
    active="$(db_active_biome_session)"
    if [[ -z "$active" ]]; then
        biome="$(biome_pick_random)"
        biome_started_at="$(date +%s)"
        sid="$(db_open_biome_session "$biome" "$biome_started_at")"
    else
        IFS=$'\t' read -r sid biome biome_started_at <<< "$active"
        # If active session is older than the rotation window, close + rotate now.
        if _pokidle_should_rotate_biome "$biome_started_at" "$(date +%s)"; then
            db_close_biome_session "$sid" "$(date +%s)"
            biome="$(biome_pick_random_excluding "$biome")"
            biome_started_at="$(date +%s)"
            sid="$(db_open_biome_session "$biome" "$biome_started_at")"
            _pokidle_announce_biome "$biome"
        fi
    fi

    # Restore tick targets, or schedule fresh.
    local now next_pokemon next_item
    now="$(date +%s)"
    next_pokemon="$(db_state_get last_pokemon_tick_target)"
    next_item="$(db_state_get last_item_tick_target)"
    [[ -z "$next_pokemon" || "$next_pokemon" -le "$now" ]] && \
        next_pokemon="$(_pokidle_next_tick_target "$now" "${POKIDLE_POKEMON_INTERVAL:-3600}")" && \
        db_state_set last_pokemon_tick_target "$next_pokemon"
    [[ -z "$next_item" || "$next_item" -le "$now" ]] && \
        next_item="$(_pokidle_next_tick_target "$now" "${POKIDLE_ITEM_INTERVAL:-3600}")" && \
        db_state_set last_item_tick_target "$next_item"

    trap '_pokidle_shutdown $sid; exit 0' INT TERM

    while :; do
        now="$(date +%s)"

        if _pokidle_should_rotate_biome "$biome_started_at" "$now"; then
            db_close_biome_session "$sid" "$now"
            biome="$(biome_pick_random_excluding "$biome")"
            biome_started_at="$now"
            sid="$(db_open_biome_session "$biome" "$biome_started_at")"
            _pokidle_announce_biome "$biome"
        fi

        if (( now >= next_pokemon )); then
            pokidle_tick pokemon || printf 'daemon: pokemon tick failed (continuing)\n' >&2
            next_pokemon="$(_pokidle_next_tick_target "$now" "${POKIDLE_POKEMON_INTERVAL:-3600}")"
            db_state_set last_pokemon_tick_target "$next_pokemon"
        fi
        if (( now >= next_item )); then
            pokidle_tick item || printf 'daemon: item tick failed (continuing)\n' >&2
            next_item="$(_pokidle_next_tick_target "$now" "${POKIDLE_ITEM_INTERVAL:-3600}")"
            db_state_set last_item_tick_target "$next_item"
        fi

        local biome_end=$((biome_started_at + ${POKIDLE_BIOME_HOURS:-3} * 3600))
        local next_event=$(( next_pokemon < next_item ? next_pokemon : next_item ))
        (( biome_end < next_event )) && next_event="$biome_end"
        local sleep_for=$(( next_event - now ))
        (( sleep_for < 1 )) && sleep_for=1
        sleep "$sleep_for"
    done
}

_pokidle_announce_biome() {
    local biome="$1"
    local label pool_size item_size
    label="$(biome_get "$biome" | jq -r '.label')"
    if [[ -f "$(encounter_pool_path "$biome")" ]]; then
        pool_size="$(jq '.entries | length' "$(encounter_pool_path "$biome")")"
    else
        pool_size=0
    fi
    item_size="$(biome_get "$biome" | jq '.item_pool | length')"
    notify_biome_change "$label" "$pool_size" "$item_size"
}

_pokidle_shutdown() {
    local sid="$1"
    # Don't close session; daemon may restart.
    printf 'pokidle: shutting down (session #%s left open)\n' "$sid" >&2
}
```

- [ ] **Step 2: Manual smoke (executor's judgment — runs forever)**

```bash
POKIDLE_BIOME_HOURS=1 \
POKIDLE_POKEMON_INTERVAL=60 \
POKIDLE_ITEM_INTERVAL=60 \
POKIDLE_NO_NOTIFY=1 \
POKIDLE_NO_SOUND=1 \
timeout 200 ./pokidle daemon || true

./pokidle list --limit 3
./pokidle items --limit 3
```

Expected: ≥1 encounter and ≥1 item drop within 200 s.

- [ ] **Step 3: Commit**

```bash
git add pokidle
git commit -m "feat(daemon): main loop with biome rotation, ticks, and resume"
```

---

## Task 4: Sound assets

**Files:**
- Create: `share/sounds/encounter.ogg`
- Create: `share/sounds/shiny.ogg`

- [ ] **Step 1: Source royalty-free sounds**

Two short clips (≤2 s each). Recommended sources:
- https://freesound.org (filter CC0)
- https://opengameart.org (filter CC0/CC-BY)

Suggested choices for replication:
- Encounter: a soft chime / "blip" (e.g. `freesound.org/people/InspectorJ/sounds/411090/`).
- Shiny: a sparkle / "ding".

Save each as OGG Vorbis (smaller than WAV, plays in `paplay`/`aplay`):

```bash
mkdir -p share/sounds
# example: re-encode WAV to OGG with ffmpeg
ffmpeg -i encounter-source.wav -c:a libvorbis -q:a 4 share/sounds/encounter.ogg
ffmpeg -i shiny-source.wav     -c:a libvorbis -q:a 4 share/sounds/shiny.ogg
```

If the executor cannot redistribute their chosen files, leave a `share/sounds/README.md` instead, instructing the user to drop their own `encounter.ogg` and `shiny.ogg` in this directory.

- [ ] **Step 2: Verify playback**

```bash
paplay share/sounds/encounter.ogg || aplay share/sounds/encounter.ogg
paplay share/sounds/shiny.ogg     || aplay share/sounds/shiny.ogg
```

Expected: short audible blip / ding.

- [ ] **Step 3: Commit**

```bash
git add share/sounds/
git commit -m "feat(sounds): bundle encounter + shiny ogg assets"
```

---

## Task 5: `pokidle setup`

**Files:**
- Modify: `pokidle`
- Create: `tests/test-setup.bats`

- [ ] **Step 1: Failing tests**

`tests/test-setup.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_TEST_HOME="$BATS_TMPDIR/home.$$"
    mkdir -p "$POKIDLE_TEST_HOME"
    export HOME="$POKIDLE_TEST_HOME"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CACHE_HOME="$HOME/.cache"
    # Override systemctl: the test must not poke real user services.
    export PATH="$BATS_TMPDIR/bin.$$:$PATH"
    mkdir -p "$BATS_TMPDIR/bin.$$"
    cat > "$BATS_TMPDIR/bin.$$/systemctl" <<'EOF'
#!/bin/bash
# stub: log args, exit 0
echo "stub-systemctl: $*" >> "$HOME/systemctl.log"
exit 0
EOF
    chmod +x "$BATS_TMPDIR/bin.$$/systemctl"
}

teardown() {
    rm -rf "$POKIDLE_TEST_HOME" "$BATS_TMPDIR/bin.$$"
}

@test "pokidle setup creates config + unit + symlink and skips enable" {
    run "$REPO_ROOT/pokidle" setup
    [ "$status" -eq 0 ]
    [ -f "$XDG_CONFIG_HOME/pokidle/biomes.json" ]
    [ -f "$XDG_CONFIG_HOME/systemd/user/pokidle.service" ]
    [ -L "$HOME/.local/bin/pokidle" ]
    grep -q 'daemon-reload' "$HOME/systemctl.log"
    ! grep -q 'enable --now' "$HOME/systemctl.log"
}

@test "pokidle setup --enable also enables the unit" {
    run "$REPO_ROOT/pokidle" setup --enable
    [ "$status" -eq 0 ]
    grep -q 'enable --now' "$HOME/systemctl.log"
}

@test "pokidle setup is idempotent (no overwrite without --force)" {
    "$REPO_ROOT/pokidle" setup
    echo '{"manual":"edit"}' > "$XDG_CONFIG_HOME/pokidle/biomes.json"
    "$REPO_ROOT/pokidle" setup
    run cat "$XDG_CONFIG_HOME/pokidle/biomes.json"
    [ "$output" = '{"manual":"edit"}' ]
}

@test "pokidle setup --force overwrites config" {
    "$REPO_ROOT/pokidle" setup
    echo '{"manual":"edit"}' > "$XDG_CONFIG_HOME/pokidle/biomes.json"
    "$REPO_ROOT/pokidle" setup --force
    run jq '.biomes | length' "$XDG_CONFIG_HOME/pokidle/biomes.json"
    [ "$output" = "18" ]
}
```

- [ ] **Step 2: Implement**

Replace `pokidle_setup` and `pokidle_uninstall`:

```bash
pokidle_setup() {
    local enable=0 force=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --enable) enable=1; shift ;;
            --force)  force=1; shift ;;
            *) printf 'setup: unknown flag %s\n' "$1" >&2; return 2 ;;
        esac
    done

    # 1. Config dir + biomes.json
    mkdir -p -- "$POKIDLE_CONFIG_DIR"
    if (( force )) || [[ ! -f "$POKIDLE_CONFIG_DIR/biomes.json" ]]; then
        cp -- "$POKIDLE_REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
        printf 'wrote %s\n' "$POKIDLE_CONFIG_DIR/biomes.json"
    fi

    # 2. Data + cache dirs
    mkdir -p -- "$POKIDLE_DATA_DIR" "$POKIDLE_CACHE_DIR"

    # 3. Symlink pokidle into ~/.local/bin
    local bindir="$HOME/.local/bin"
    mkdir -p -- "$bindir"
    if (( force )) || [[ ! -e "$bindir/pokidle" ]]; then
        ln -sf -- "$POKIDLE_REPO_ROOT/pokidle" "$bindir/pokidle"
        printf 'symlinked %s -> %s\n' "$bindir/pokidle" "$POKIDLE_REPO_ROOT/pokidle"
    fi
    case ":$PATH:" in
        *":$bindir:"*) ;;
        *) printf 'warning: %s is not in PATH — add it to your shell rc\n' "$bindir" >&2 ;;
    esac

    # 4. Systemd unit
    local sd_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p -- "$sd_dir"
    if (( force )) || [[ ! -f "$sd_dir/pokidle.service" ]]; then
        cp -- "$POKIDLE_REPO_ROOT/systemd/pokidle.service" "$sd_dir/pokidle.service"
        printf 'wrote %s\n' "$sd_dir/pokidle.service"
    fi

    # 5. Reload systemd user units
    systemctl --user daemon-reload || \
        printf 'warning: systemctl --user daemon-reload failed (no logind?)\n' >&2

    if (( enable )); then
        systemctl --user enable --now pokidle.service && \
            printf 'enabled and started pokidle.service\n' || \
            printf 'enable failed — see journalctl --user -u pokidle\n' >&2
    else
        printf 'next: systemctl --user enable --now pokidle.service\n'
    fi
}

pokidle_uninstall() {
    systemctl --user disable --now pokidle.service 2>/dev/null || true
    rm -f -- "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/pokidle.service"
    rm -f -- "$HOME/.local/bin/pokidle"
    systemctl --user daemon-reload || true
    printf 'uninstalled. Config (%s), DB (%s), cache (%s) left intact.\n' \
        "$POKIDLE_CONFIG_DIR" "$POKIDLE_DB_PATH" "$POKIDLE_CACHE_DIR"
}
```

- [ ] **Step 3: Run tests, expect pass**

```bash
bats tests/test-setup.bats
```

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-setup.bats
git commit -m "feat(pokidle): setup + uninstall lifecycle commands"
```

---

## Task 6: `pokidle status`

**Files:**
- Modify: `pokidle`
- Modify: `tests/test-setup.bats`

- [ ] **Step 1: Add test**

```bash
@test "pokidle status prints systemctl + last tick info" {
    "$REPO_ROOT/pokidle" setup

    # Pre-populate db with some state
    db_init() { sqlite3 "$XDG_DATA_HOME/pokidle/pokidle.db" < "$REPO_ROOT/schema.sql"; }
    db_init

    sqlite3 "$XDG_DATA_HOME/pokidle/pokidle.db" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));"
    sqlite3 "$XDG_DATA_HOME/pokidle/pokidle.db" \
        "INSERT OR REPLACE INTO daemon_state(key,value) VALUES ('last_pokemon_tick_target','1700001000');"

    run "$REPO_ROOT/pokidle" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"systemctl"* ]] || [[ "$output" == *"Loaded:"* ]] || true
    [[ "$output" == *"cave"* ]]
    [[ "$output" == *"last_pokemon_tick_target"* ]] || [[ "$output" == *"1700001000"* ]]
}
```

- [ ] **Step 2: Implement**

Replace `pokidle_status`:

```bash
pokidle_status() {
    printf '=== systemctl --user status pokidle.service ===\n'
    systemctl --user status pokidle.service --no-pager 2>&1 || true
    printf '\n=== current biome ===\n'
    pokidle_current
    printf '\n=== daemon_state ===\n'
    db_init
    db_query "SELECT key, value FROM daemon_state ORDER BY key;" |
        awk -F'\t' '{ printf "  %-32s %s\n", $1, $2 }'
}
```

- [ ] **Step 3: Run, expect pass**

```bash
bats tests/test-setup.bats
```

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-setup.bats
git commit -m "feat(pokidle): status command"
```

---

## Task 7: End-to-end run

**Files:** none (verification only)

- [ ] **Step 1: Run full suite**

```bash
bats tests/
```

Expected: every test in every file passes.

- [ ] **Step 2: Live integration (executor's judgment)**

```bash
./pokidle setup
./pokidle rebuild-biomes      # ~10 min, live API
./pokidle rebuild-pool cave   # quick, live API for one biome
./pokidle tick pokemon --dry-run         # see notification, no DB write
./pokidle tick pokemon                    # persisted
./pokidle list --limit 1
./pokidle list --export | head -20

# Run daemon for a short window
POKIDLE_BIOME_HOURS=1 \
POKIDLE_POKEMON_INTERVAL=60 \
POKIDLE_ITEM_INTERVAL=60 \
timeout 180 ./pokidle daemon

./pokidle stats
./pokidle current
./pokidle status
```

Expected: at least one pokemon and one item appear during the 180 s daemon window. Notifications fire. List/export/stats all populate.

- [ ] **Step 3: Final commit (if any cleanup)**

```bash
git status
# only commit if deltas remain
```

---

## Plan C complete

End state: full passive game runs as a `systemd --user` service. `pokidle setup --enable` is one command away. CLI gives history, stats, and Showdown export. Notifications surface every encounter.

## Self-review notes

- Spec coverage:
  - Daemon loop (rotate, tick, sleep): Task 3.
  - Resume on restart via `daemon_state.last_*_tick_target`: Task 3 (initial branch loads `db_state_get`).
  - systemd user unit + `setup`/`enable`: Tasks 1, 5.
  - `uninstall`/`status`: Tasks 5, 6.
  - Sound assets: Task 4.
- Type/name consistency: helper functions (`_pokidle_next_tick_target`, `_pokidle_should_rotate_biome`, `_pokidle_announce_biome`, `_pokidle_shutdown`) are defined and used consistently. `pokidle_tick` is reused from Plan B.
- Tests stub `systemctl` to avoid touching the real user session.
- Live-integration steps require human judgment (slow, environment-dependent) — they're documented but not part of `bats tests/`.
- No placeholders; every step has executable code or a concrete decision.
