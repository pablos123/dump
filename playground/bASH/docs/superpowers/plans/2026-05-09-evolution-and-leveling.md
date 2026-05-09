# Evolution + Level-Up + Friendship Loops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three background loops that mutate current-week encounters: hourly level-up, half-hourly friendship gain, and per-biome-rotation evolution. Encounters gain a `friendship` column populated from species `base_happiness` at insert time.

**Architecture:** Reuse the existing daemon-timer pattern (`last_*_tick_target` keys in `daemon_state`) for the new level + friendship timers. Evolution piggybacks on the existing biome-rotation point in `pokidle_daemon`. Logic lives in `lib/encounter.bash` (helpers reused) and a new `lib/evolution.bash` (path enumeration, condition checks). DB writes go through new wrapper functions in `lib/db.bash`. CLI gets `tick level | friendship | evolve` subcommands.

**Tech Stack:** Bash 5+, sqlite3, jq, bats-core. Existing `pokeapi_get` cache layer for /pokemon-species and /evolution-chain calls.

**Spec:** `docs/superpowers/specs/2026-05-09-evolution-and-leveling-design.md`

---

## File map

- Modify `schema.sql` — add `friendship INTEGER NOT NULL DEFAULT 70` to `encounters`. Add column for legacy DBs via `db_init` ALTER.
- Modify `lib/db.bash` — add `db_list_current_week_encounters`, `db_update_encounter_level_stats`, `db_update_encounter_friendship`, `db_update_encounter_evolved`, `db_delete_one_item_drop`. Update `db_init` to ALTER legacy DBs.
- Modify `lib/encounter.bash` — add `encounter_roll_friendship`. Hook into `encounter_roll_pokemon` so emitted encounter JSON carries `friendship`. Update `db_insert_encounter` (in `lib/db.bash`) to write friendship column.
- Create `lib/evolution.bash` — `evolution_tier_lookup`, `evolution_next_stages`, `evolution_check_hard_filters`, `evolution_path_kind`, `evolution_pick_path`, `evolution_apply`.
- Modify `pokidle` — add `pokidle_tick_level`, `pokidle_tick_friendship`, `pokidle_tick_evolve`. Extend `pokidle_tick` dispatch and `case` in dispatcher. Wire 4th/5th daemon timers and biome-rotation hook. Update `pokidle_switch_biome` to fire evolution loop.
- Create `tests/test-leveling.bats`, `tests/test-friendship.bats`, `tests/test-evolution.bats`.
- Modify `tests/helpers.bash` — small additions if needed for time-mocking.

## Conventions

- Test runner: `bats tests/<file>.bats`. Full suite: `bats tests/`.
- Each task is TDD: failing test first, then implementation, then commit.
- Friendship default for legacy rows is `70`. New rows pull `base_happiness` from `/pokemon-species/<species>`.

---

## Task 1: Schema — add friendship column

**Files:**
- Modify: `schema.sql`
- Modify: `lib/db.bash:17-25` (`db_init`)
- Test: extend `tests/test-db.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-db.bats`:

```bash
@test "db_init creates encounters with friendship column (default 70)" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    local cols
    cols="$(sqlite3 "$POKIDLE_DB_PATH" "PRAGMA table_info(encounters);" | grep '|friendship|')"
    [[ -n "$cols" ]]
    [[ "$cols" == *"|70|"* ]]
}

@test "db_init adds friendship column to legacy DB without recreate" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    # Hand-build a v1 schema (no friendship).
    sqlite3 "$POKIDLE_DB_PATH" "
        CREATE TABLE biome_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, biome_id TEXT NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER);
        CREATE TABLE encounters (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL, encountered_at INTEGER NOT NULL, species TEXT NOT NULL, dex_id INTEGER NOT NULL, level INTEGER NOT NULL, nature TEXT NOT NULL, ability TEXT NOT NULL, is_hidden_ability INTEGER NOT NULL, gender TEXT NOT NULL, shiny INTEGER NOT NULL, held_berry TEXT, iv_hp INTEGER, iv_atk INTEGER, iv_def INTEGER, iv_spa INTEGER, iv_spd INTEGER, iv_spe INTEGER, ev_hp INTEGER, ev_atk INTEGER, ev_def INTEGER, ev_spa INTEGER, ev_spd INTEGER, ev_spe INTEGER, stat_hp INTEGER, stat_atk INTEGER, stat_def INTEGER, stat_spa INTEGER, stat_spd INTEGER, stat_spe INTEGER, moves_json TEXT NOT NULL, sprite_path TEXT);
        CREATE TABLE item_drops (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL, encountered_at INTEGER NOT NULL, item TEXT NOT NULL, sprite_path TEXT);
        CREATE TABLE daemon_state (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level, nature, ability, is_hidden_ability, gender, shiny, moves_json) VALUES (1, 1700000000, 'rattata', 19, 5, 'hardy', 'guts', 0, 'M', 0, '[]');
    "
    load_lib db
    db_init
    local fr
    fr="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT friendship FROM encounters WHERE id=1;")"
    [ "$fr" = "70" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-db.bats -f friendship`
Expected: both new tests FAIL — column doesn't exist.

- [ ] **Step 3: Update schema.sql**

In `schema.sql`, add `friendship INTEGER NOT NULL DEFAULT 70,` immediately after the `held_berry` line (line 24):

```sql
    gender          TEXT NOT NULL,
    shiny           INTEGER NOT NULL,
    held_berry      TEXT,
    friendship      INTEGER NOT NULL DEFAULT 70,
    iv_hp INTEGER, iv_atk INTEGER, iv_def INTEGER,
```

- [ ] **Step 4: Update `db_init` to ALTER legacy DBs**

Replace `db_init` body (`lib/db.bash:17-25`) with:

```bash
db_init() {
    local schema="${POKIDLE_REPO_ROOT}/schema.sql"
    if [[ ! -f "$schema" ]]; then
        printf 'db_init: schema.sql not found at %s\n' "$schema" >&2
        return 1
    fi
    mkdir -p -- "$(dirname -- "$POKIDLE_DB_PATH")"
    sqlite3 "$POKIDLE_DB_PATH" < "$schema"
    # Idempotent backfill for legacy DBs (encounters table existed before
    # the friendship column was added).
    if ! sqlite3 "$POKIDLE_DB_PATH" \
            "SELECT 1 FROM pragma_table_info('encounters') WHERE name='friendship';" \
            | grep -q 1; then
        sqlite3 "$POKIDLE_DB_PATH" \
            "ALTER TABLE encounters ADD COLUMN friendship INTEGER NOT NULL DEFAULT 70;"
    fi
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats tests/test-db.bats`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add schema.sql lib/db.bash tests/test-db.bats
git commit -m "db: add friendship column to encounters w/ legacy backfill"
```

---

## Task 2: `encounter_roll_friendship` helper

**Files:**
- Modify: `lib/encounter.bash` — append at end of file
- Test: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-rolls.bats`:

```bash
@test "encounter_roll_friendship returns species base_happiness" {
    # Stub returns a /pokemon-species response with base_happiness=50.
    pokeapi_get() {
        case "$1" in
            pokemon-species/eevee)
                printf '{"base_happiness":50}'
                ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get
    run encounter_roll_friendship eevee
    [ "$status" -eq 0 ]
    [ "$output" = "50" ]
}

@test "encounter_roll_friendship defaults to 70 if base_happiness missing" {
    pokeapi_get() {
        printf '{}'
    }
    export -f pokeapi_get
    run encounter_roll_friendship some-species
    [ "$status" -eq 0 ]
    [ "$output" = "70" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-encounter-rolls.bats -f encounter_roll_friendship`
Expected: FAIL.

- [ ] **Step 3: Add `encounter_roll_friendship` at end of `lib/encounter.bash`**

Append:

```bash
# Pull species base_happiness from PokeAPI. Defaults to 70 if missing.
encounter_roll_friendship() {
    local species="$1"
    local spec
    spec="$(pokeapi_get "pokemon-species/$species")" || return 1
    local val
    val="$(jq -r '.base_happiness // 70' <<< "$spec")"
    [[ "$val" == "null" || -z "$val" ]] && val=70
    printf '%s' "$val"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-encounter-rolls.bats -f encounter_roll_friendship`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-rolls.bats
git commit -m "encounter: add base_happiness friendship helper"
```

---

## Task 3: Hook friendship into `encounter_roll_pokemon`

**Files:**
- Modify: `lib/encounter.bash` — `encounter_roll_pokemon` (locate by name; ends ~line 580)
- Test: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-rolls.bats`:

```bash
@test "encounter_roll_pokemon: encounter JSON includes friendship from species" {
    # Reuse existing fixtures + override pokeapi_get for species call.
    local entry='{"species":"treecko","min":5,"max":7}'
    run encounter_roll_pokemon "$entry" "forest"
    [ "$status" -eq 0 ]
    local fr
    fr="$(jq -r '.friendship' <<< "$output")"
    [[ "$fr" =~ ^[0-9]+$ ]]
    (( fr >= 0 && fr <= 255 ))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/test-encounter-rolls.bats -f "encounter JSON includes friendship"`
Expected: FAIL — emitted JSON lacks `friendship`.

- [ ] **Step 3: Modify `encounter_roll_pokemon`**

Find the final `jq -n` invocation in `encounter_roll_pokemon` (the one that builds the final encounter JSON). Insert a new `friendship` roll above the `jq -n` call and add `friendship` to the JSON output:

Locate the block that starts with `local berry_arg`. Before that block, add:

```bash
    local friendship
    friendship="$(encounter_roll_friendship "$sp")" || return 1
```

Then update the final `jq -n` call to include `--argjson friendship "$friendship"` in the args list and `friendship: $friendship,` in the constructed object — placed immediately after `held_berry: $held,`.

The final `jq -n ...` should look like:

```bash
    jq -n \
        --arg sp "$sp" --argjson dex "$dex_id" --argjson lvl "$level" \
        --arg nature "$nature" --arg ability "$ability" --argjson hidden "$is_hidden" \
        --arg gender "$gender" --argjson shiny "$shiny" --argjson held "$berry_arg" \
        --argjson friendship "$friendship" \
        --argjson ivs "$ivs_json" --argjson evs "$evs_json" --argjson stats "$stats_json" \
        --argjson moves "$moves_json" --arg sprite "$final_sprite" '{
            species: $sp, dex_id: $dex, level: $lvl,
            nature: $nature, ability: $ability, is_hidden_ability: $hidden,
            gender: $gender, shiny: $shiny, held_berry: $held,
            friendship: $friendship,
            ivs: $ivs, evs: $evs, stats: $stats,
            moves: $moves, sprite_url: $sprite
        }'
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-encounter-rolls.bats`
Expected: every test passes (including the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-rolls.bats
git commit -m "encounter: include friendship in roll output"
```

---

## Task 4: Persist friendship in `db_insert_encounter`

**Files:**
- Modify: `lib/db.bash:61-95` (`db_insert_encounter`)
- Test: `tests/test-db.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-db.bats`:

```bash
@test "db_insert_encounter persists friendship value" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);"
    local enc
    enc='{"session_id":1,"encountered_at":1700000000,"species":"eevee","dex_id":133,"level":5,"nature":"hardy","ability":"run-away","is_hidden_ability":0,"gender":"M","shiny":0,"held_berry":null,"friendship":50,"ivs":[10,10,10,10,10,10],"evs":[0,0,0,0,0,0],"stats":[20,11,11,11,11,11],"moves":["tackle"],"sprite_path":""}'
    db_insert_encounter "$enc"
    local fr
    fr="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT friendship FROM encounters WHERE id=1;")"
    [ "$fr" = "50" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/test-db.bats -f "persists friendship"`
Expected: FAIL — column not in INSERT list.

- [ ] **Step 3: Update `db_insert_encounter`**

In `lib/db.bash`, find the `INSERT INTO encounters (` block in the heredoc. Add `friendship` to both the column list and the values list. The updated heredoc:

```sql
"INSERT INTO encounters (
    session_id, encountered_at, species, dex_id, level,
    nature, ability, is_hidden_ability, gender, shiny, held_berry,
    friendship,
    iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
    ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe,
    stat_hp, stat_atk, stat_def, stat_spa, stat_spd, stat_spe,
    moves_json, sprite_path
) VALUES (
    \(.session_id),
    \(.encountered_at),
    \(.species | sqstr),
    \(.dex_id),
    \(.level),
    \(.nature | sqstr),
    \(.ability | sqstr),
    \(.is_hidden_ability),
    \(.gender | sqstr),
    \(.shiny),
    \(.held_berry | sqstr),
    \(.friendship),
    \(.ivs[0]), \(.ivs[1]), \(.ivs[2]), \(.ivs[3]), \(.ivs[4]), \(.ivs[5]),
    \(.evs[0]), \(.evs[1]), \(.evs[2]), \(.evs[3]), \(.evs[4]), \(.evs[5]),
    \(.stats[0]), \(.stats[1]), \(.stats[2]), \(.stats[3]), \(.stats[4]), \(.stats[5]),
    \(.moves | tojson | sqstr),
    \(.sprite_path | sqstr)
);"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-db.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "db: persist friendship in db_insert_encounter"
```

---

## Task 5: Current-week candidate query

**Files:**
- Modify: `lib/db.bash` — append below `db_list_encounters`
- Test: `tests/test-db.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-db.bats`:

```bash
@test "db_list_current_week_encounters returns rows in current ISO week only" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init

    # Compute Monday 00:00 local of this week.
    local mon_ts now
    now="$(date +%s)"
    mon_ts="$(date -d "$(date -d 'this monday' +%F) 00:00:00" +%s 2>/dev/null \
              || date -v-mon -v0H -v0M -v0S +%s)"
    local last_week=$((mon_ts - 7*86400))
    local this_week=$((mon_ts + 3*86400))

    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $mon_ts);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship)
            VALUES (1, $last_week, 'rattata', 19, 3, 'hardy', 'guts', 0, 'M', 0, '[]', 70),
                   (1, $this_week, 'pidgey',  16, 4, 'hardy', 'keen-eye', 0, 'M', 0, '[]', 70);
    "
    run db_list_current_week_encounters
    [ "$status" -eq 0 ]
    [ "$(jq 'length' <<< "$output")" = "1" ]
    [ "$(jq -r '.[0].species' <<< "$output")" = "pidgey" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/test-db.bats -f "current ISO week"`
Expected: FAIL.

- [ ] **Step 3: Implement helper**

Append to `lib/db.bash`:

```bash
# Returns JSON array of encounter rows whose encountered_at falls within
# the current local ISO week (Mon 00:00 — Sun 23:59:59).
db_list_current_week_encounters() {
    local mon_ts sun_ts
    mon_ts="$(date -d "$(date -d 'this monday' +%F) 00:00:00" +%s 2>/dev/null \
              || date -v-mon -v0H -v0M -v0S +%s)"
    sun_ts=$((mon_ts + 7*86400 - 1))
    db_query_json "
        SELECT * FROM encounters
        WHERE encountered_at BETWEEN $mon_ts AND $sun_ts
        ORDER BY id ASC;"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-db.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "db: add current-week encounter listing helper"
```

---

## Task 6: DB update wrappers

**Files:**
- Modify: `lib/db.bash` — append below the new `db_list_current_week_encounters`
- Test: `tests/test-db.bats`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-db.bats`:

```bash
@test "db_update_encounter_level_stats updates level + 6 stat columns" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json,
            friendship, stat_hp, stat_atk, stat_def, stat_spa, stat_spd, stat_spe)
            VALUES (1, 1700000000, 'rattata', 19, 5, 'hardy', 'guts', 0, 'M', 0, '[]',
                70, 20, 11, 10, 8, 9, 14);"
    run db_update_encounter_level_stats 1 6 "21 12 11 9 10 15"
    [ "$status" -eq 0 ]
    local row
    row="$(sqlite3 "$POKIDLE_DB_PATH" \
        "SELECT level||','||stat_hp||','||stat_atk||','||stat_def||','||stat_spa||','||stat_spd||','||stat_spe FROM encounters WHERE id=1;")"
    [ "$row" = "6,21,12,11,9,10,15" ]
}

@test "db_update_encounter_friendship caps at 255" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship)
            VALUES (1, 1700000000, 'rattata', 19, 5, 'hardy', 'guts', 0, 'M', 0, '[]', 70);"
    db_update_encounter_friendship 1 75
    local v
    v="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT friendship FROM encounters WHERE id=1;")"
    [ "$v" = "75" ]
}

@test "db_update_encounter_evolved updates species, dex_id, sprite, stats" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json,
            friendship, sprite_path)
            VALUES (1, 1700000000, 'eevee', 133, 20, 'hardy', 'run-away', 0, 'M', 0, '[]',
                70, 'old.png');"
    db_update_encounter_evolved 1 vaporeon 134 "new.png" "60 30 30 50 50 30"
    local row
    row="$(sqlite3 "$POKIDLE_DB_PATH" \
        "SELECT species||','||dex_id||','||sprite_path||','||stat_hp||','||stat_atk||','||stat_def||','||stat_spa||','||stat_spd||','||stat_spe FROM encounters WHERE id=1;")"
    [ "$row" = "vaporeon,134,new.png,60,30,30,50,50,30" ]
}

@test "db_delete_one_item_drop deletes oldest matching row only" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);
        INSERT INTO item_drops(session_id, encountered_at, item) VALUES
            (1, 100, 'water-stone'),
            (1, 200, 'water-stone'),
            (1, 300, 'fire-stone');"
    run db_delete_one_item_drop water-stone
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
    local n_water n_fire
    n_water="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM item_drops WHERE item='water-stone';")"
    n_fire="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM item_drops WHERE item='fire-stone';")"
    [ "$n_water" = "1" ]
    [ "$n_fire" = "1" ]
}

@test "db_delete_one_item_drop returns 0 when no match" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    run db_delete_one_item_drop never-stone
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-db.bats`
Expected: 5 new tests FAIL.

- [ ] **Step 3: Implement helpers**

Append to `lib/db.bash`:

```bash
# Update level + stat_* columns of encounter <id>.
# stats_str is "hp atk def spa spd spe" (space-separated integers).
db_update_encounter_level_stats() {
    local id="$1" level="$2" stats_str="$3"
    _db_assert_int "$id" id || return $?
    _db_assert_int "$level" level || return $?
    local stats=($stats_str)
    local s
    for s in "${stats[@]}"; do
        _db_assert_int "$s" stat || return $?
    done
    db_exec "UPDATE encounters
        SET level=$level,
            stat_hp=${stats[0]}, stat_atk=${stats[1]}, stat_def=${stats[2]},
            stat_spa=${stats[3]}, stat_spd=${stats[4]}, stat_spe=${stats[5]}
        WHERE id=$id;"
}

db_update_encounter_friendship() {
    local id="$1" friendship="$2"
    _db_assert_int "$id" id || return $?
    _db_assert_int "$friendship" friendship || return $?
    db_exec "UPDATE encounters SET friendship=$friendship WHERE id=$id;"
}

# Update species/dex_id/sprite_path + 6 stat columns after evolution.
db_update_encounter_evolved() {
    local id="$1" species="$2" dex_id="$3" sprite="$4" stats_str="$5"
    _db_assert_int "$id" id || return $?
    _db_assert_int "$dex_id" dex_id || return $?
    local stats=($stats_str)
    local s
    for s in "${stats[@]}"; do
        _db_assert_int "$s" stat || return $?
    done
    local sprite_sql="NULL"
    [[ -n "$sprite" ]] && sprite_sql="'${sprite//\'/\'\'}'"
    db_exec "UPDATE encounters
        SET species='${species//\'/\'\'}', dex_id=$dex_id, sprite_path=$sprite_sql,
            stat_hp=${stats[0]}, stat_atk=${stats[1]}, stat_def=${stats[2]},
            stat_spa=${stats[3]}, stat_spd=${stats[4]}, stat_spe=${stats[5]}
        WHERE id=$id;"
}

# Delete the oldest item_drops row whose item equals <name>. Prints count
# of deleted rows (0 or 1).
db_delete_one_item_drop() {
    local item="$1"
    local id
    id="$(db_query "SELECT id FROM item_drops
                    WHERE item='${item//\'/\'\'}'
                    ORDER BY id ASC LIMIT 1;")"
    if [[ -z "$id" ]]; then
        printf '0'
        return 0
    fi
    db_exec "DELETE FROM item_drops WHERE id=$id;"
    printf '1'
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-db.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "db: add update wrappers for level/friendship/evolved + item delete"
```

---

## Task 7: `pokidle_tick_level`

**Files:**
- Modify: `pokidle` — add new function below `pokidle_tick`
- Create: `tests/test-leveling.bats`

- [ ] **Step 1: Create failing tests**

Create `tests/test-leveling.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/pcache.$$"
    POKEAPI_CACHE_DIR="$BATS_TMPDIR/papi.$$"
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/pcfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR" "$POKIDLE_CACHE_DIR" "$POKEAPI_CACHE_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR POKEAPI_CACHE_DIR POKIDLE_CONFIG_DIR

    # Stub pokeapi for stats recompute.
    pokeapi_get() {
        case "$1" in
            pokemon/rattata)
                printf '%s' '{"stats":[
                    {"base_stat":30,"stat":{"name":"hp"}},
                    {"base_stat":56,"stat":{"name":"attack"}},
                    {"base_stat":35,"stat":{"name":"defense"}},
                    {"base_stat":25,"stat":{"name":"special-attack"}},
                    {"base_stat":35,"stat":{"name":"special-defense"}},
                    {"base_stat":72,"stat":{"name":"speed"}}]}'
                ;;
            nature/hardy)
                printf '%s' '{"increased_stat":null,"decreased_stat":null}'
                ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get
}

teardown() {
    rm -rf "$POKIDLE_CACHE_DIR" "$POKEAPI_CACHE_DIR" "$POKIDLE_CONFIG_DIR"
}

_seed_rattata_in_current_week() {
    local mon_ts
    mon_ts="$(date -d "$(date -d 'this monday' +%F) 00:00:00" +%s 2>/dev/null \
              || date -v-mon -v0H -v0M -v0S +%s)"
    local now=$((mon_ts + 86400))   # tuesday
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', $mon_ts);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json,
            friendship, iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe,
            stat_hp, stat_atk, stat_def, stat_spa, stat_spd, stat_spe)
            VALUES (1, $now, 'rattata', 19, 5, 'hardy', 'guts', 0, 'M', 0, '[]', 70,
                10,10,10,10,10,10, 0,0,0,0,0,0,
                17, 13, 11, 9, 10, 14);"
}

@test "pokidle tick level --json bumps eligible candidate when roll < 25" {
    _seed_rattata_in_current_week
    # RANDOM is non-deterministic; loop a few times to get a level-up event.
    local i hit=0 out
    for i in {1..40}; do
        out="$("$REPO_ROOT/pokidle" tick level --dry-run --no-notify --json 2>/dev/null)"
        [ -n "$out" ] || continue
        local n
        n="$(jq '.leveled | length' <<< "$out")"
        if (( n > 0 )); then
            hit=1
            local from to id
            from="$(jq -r '.leveled[0].from' <<< "$out")"
            to="$(jq -r '.leveled[0].to' <<< "$out")"
            [ "$from" = "5" ]
            [ "$to" = "6" ]
            break
        fi
    done
    [ "$hit" = "1" ]
}

@test "pokidle tick level: dry-run does not write to DB" {
    _seed_rattata_in_current_week
    "$REPO_ROOT/pokidle" tick level --dry-run --no-notify --json 2>/dev/null > /dev/null
    local lvl
    lvl="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT level FROM encounters WHERE id=1;")"
    [ "$lvl" = "5" ]
}

@test "pokidle tick level: level 100 candidate skipped" {
    local mon_ts
    mon_ts="$(date -d "$(date -d 'this monday' +%F) 00:00:00" +%s 2>/dev/null \
              || date -v-mon -v0H -v0M -v0S +%s)"
    local now=$((mon_ts + 86400))
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', $mon_ts);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship)
            VALUES (1, $now, 'rattata', 19, 100, 'hardy', 'guts', 0, 'M', 0, '[]', 70);"
    local i out leveled_max=0
    for i in {1..30}; do
        out="$("$REPO_ROOT/pokidle" tick level --dry-run --no-notify --json 2>/dev/null)"
        local n="$(jq '.leveled | length' <<< "$out")"
        (( n > leveled_max )) && leveled_max=$n
    done
    [ "$leveled_max" = "0" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-leveling.bats`
Expected: FAIL — `tick level` is unknown subcommand.

- [ ] **Step 3: Implement `pokidle_tick_level` and dispatch**

Add to `pokidle` immediately after `pokidle_tick` (around line 280):

```bash
pokidle_tick_level() {
    local dry_run=0 no_notify=0 emit_json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   dry_run=1; shift ;;
            --no-notify) no_notify=1; shift ;;
            --json)      emit_json=1; shift ;;
            *) printf 'tick level: unknown flag %s\n' "$1" >&2; return 2 ;;
        esac
    done

    db_init
    local rows
    rows="$(db_list_current_week_encounters)"
    local leveled='[]'
    local n
    n="$(jq 'length' <<< "$rows")"
    local i
    for (( i=0; i<n; i++ )); do
        local r id species level nature
        r="$(jq -c ".[$i]" <<< "$rows")"
        id="$(jq -r '.id' <<< "$r")"
        species="$(jq -r '.species' <<< "$r")"
        level="$(jq -r '.level' <<< "$r")"
        (( level >= 100 )) && continue
        (( RANDOM % 100 >= 25 )) && continue

        nature="$(jq -r '.nature' <<< "$r")"
        local ivs evs new_level
        ivs="$(jq -r '"\(.iv_hp) \(.iv_atk) \(.iv_def) \(.iv_spa) \(.iv_spd) \(.iv_spe)"' <<< "$r")"
        evs="$(jq -r '"\(.ev_hp) \(.ev_atk) \(.ev_def) \(.ev_spa) \(.ev_spd) \(.ev_spe)"' <<< "$r")"
        new_level=$(( level + 1 ))

        local poke base_stats mods stats
        poke="$(pokeapi_get "pokemon/$species")" || continue
        base_stats="$(jq -c '.stats' <<< "$poke")"
        mods="$(encounter_nature_mods "$nature")" || continue
        stats="$(encounter_compute_all_stats "$base_stats" "$ivs" "$evs" "$new_level" "$mods")" || continue

        if (( dry_run == 0 )); then
            db_update_encounter_level_stats "$id" "$new_level" "$stats"
        fi
        leveled="$(jq -c --argjson id "$id" --arg sp "$species" \
            --argjson from "$level" --argjson to "$new_level" \
            '. + [{id:$id, species:$sp, from:$from, to:$to}]' <<< "$leveled")"
    done

    if (( emit_json )); then
        jq -n --argjson l "$leveled" '{leveled: $l}'
    fi
}
```

Add to the dispatch `case "$cmd"` (around line 584):

```bash
        tick)           pokidle_tick "$@" ;;
```

is already there. The `pokidle_tick` function dispatches by `kind`. Modify it to support `level`. In `pokidle_tick`, after the `case "$kind" in` block, add a new arm:

```bash
        level)
            pokidle_tick_level "$@"
            ;;
```

Place it before the `*)` catch-all (between the existing `item)` arm and the unknown-kind error).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-leveling.bats`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Commit**

```bash
git add pokidle tests/test-leveling.bats
git commit -m "pokidle: add tick level subcommand and level-up loop"
```

---

## Task 8: `pokidle_tick_friendship`

**Files:**
- Modify: `pokidle`
- Create: `tests/test-friendship.bats`

- [ ] **Step 1: Create failing tests**

Create `tests/test-friendship.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/pcfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_CONFIG_DIR
}

teardown() { rm -rf "$POKIDLE_CONFIG_DIR"; }

_seed_friendly() {
    local fr="${1:-70}"
    local mon_ts
    mon_ts="$(date -d "$(date -d 'this monday' +%F) 00:00:00" +%s 2>/dev/null \
              || date -v-mon -v0H -v0M -v0S +%s)"
    local now=$((mon_ts + 86400))
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', $mon_ts);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship)
            VALUES (1, $now, 'rattata', 19, 5, 'hardy', 'guts', 0, 'M', 0, '[]', $fr);"
}

@test "pokidle tick friendship --json bumps friendship by 5 when roll < 50" {
    _seed_friendly 70
    local i hit=0 out
    for i in {1..30}; do
        out="$("$REPO_ROOT/pokidle" tick friendship --dry-run --no-notify --json 2>/dev/null)"
        local n
        n="$(jq '.befriended | length' <<< "$out")"
        if (( n > 0 )); then
            hit=1
            [ "$(jq -r '.befriended[0].from' <<< "$out")" = "70" ]
            [ "$(jq -r '.befriended[0].to' <<< "$out")" = "75" ]
            break
        fi
    done
    [ "$hit" = "1" ]
}

@test "pokidle tick friendship: caps at 255" {
    _seed_friendly 254
    local i hit=0 out
    for i in {1..30}; do
        out="$("$REPO_ROOT/pokidle" tick friendship --no-notify --json 2>/dev/null)"
        local n
        n="$(jq '.befriended | length' <<< "$out")"
        if (( n > 0 )); then
            hit=1
            [ "$(jq -r '.befriended[0].to' <<< "$out")" = "255" ]
            break
        fi
    done
    [ "$hit" = "1" ]
    local v
    v="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT friendship FROM encounters WHERE id=1;")"
    [ "$v" = "255" ]
}

@test "pokidle tick friendship: at 255 skipped" {
    _seed_friendly 255
    local i out leveled_max=0
    for i in {1..20}; do
        out="$("$REPO_ROOT/pokidle" tick friendship --dry-run --no-notify --json 2>/dev/null)"
        local n="$(jq '.befriended | length' <<< "$out")"
        (( n > leveled_max )) && leveled_max=$n
    done
    [ "$leveled_max" = "0" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-friendship.bats`
Expected: FAIL — `tick friendship` unknown.

- [ ] **Step 3: Implement `pokidle_tick_friendship`**

Add to `pokidle` after `pokidle_tick_level`:

```bash
pokidle_tick_friendship() {
    local dry_run=0 no_notify=0 emit_json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   dry_run=1; shift ;;
            --no-notify) no_notify=1; shift ;;
            --json)      emit_json=1; shift ;;
            *) printf 'tick friendship: unknown flag %s\n' "$1" >&2; return 2 ;;
        esac
    done

    db_init
    local rows
    rows="$(db_list_current_week_encounters)"
    local befriended='[]'
    local n
    n="$(jq 'length' <<< "$rows")"
    local i
    for (( i=0; i<n; i++ )); do
        local r id species fr_old fr_new
        r="$(jq -c ".[$i]" <<< "$rows")"
        id="$(jq -r '.id' <<< "$r")"
        species="$(jq -r '.species' <<< "$r")"
        fr_old="$(jq -r '.friendship' <<< "$r")"
        (( fr_old >= 255 )) && continue
        (( RANDOM % 100 >= 50 )) && continue

        fr_new=$(( fr_old + 5 ))
        (( fr_new > 255 )) && fr_new=255

        if (( dry_run == 0 )); then
            db_update_encounter_friendship "$id" "$fr_new"
        fi
        befriended="$(jq -c --argjson id "$id" --arg sp "$species" \
            --argjson from "$fr_old" --argjson to "$fr_new" \
            '. + [{id:$id, species:$sp, from:$from, to:$to}]' <<< "$befriended")"
    done

    if (( emit_json )); then
        jq -n --argjson b "$befriended" '{befriended: $b}'
    fi
}
```

Wire dispatch in `pokidle_tick`'s case block, mirror of `level)`:

```bash
        friendship)
            pokidle_tick_friendship "$@"
            ;;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-friendship.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pokidle tests/test-friendship.bats
git commit -m "pokidle: add tick friendship subcommand and friendship loop"
```

---

## Task 9: Evolution helpers — tier lookup + chain walker

**Files:**
- Create: `lib/evolution.bash`
- Modify: `pokidle` — source new lib
- Test: extend `tests/test-encounter-pool.bats`

- [ ] **Step 1: Create new lib + failing test**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "evolution_tier_lookup returns tier name for species in pool" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    cat > "$POKIDLE_CACHE_DIR/pools/cave.json" <<'EOF'
{"biome":"cave","schema":2,"tiers":{
  "common":[{"species":"zubat","min":5,"max":8}],
  "uncommon":[{"species":"golbat","min":22,"max":25}],
  "rare":[],"very_rare":[]
}}
EOF
    source "$REPO_ROOT/lib/evolution.bash"
    [ "$(evolution_tier_lookup cave zubat)" = "common" ]
    [ "$(evolution_tier_lookup cave golbat)" = "uncommon" ]
    [ "$(evolution_tier_lookup cave mew)" = "common" ]   # absent → default
}

@test "evolution_next_stages returns species + evolution_details one stage past root" {
    source "$REPO_ROOT/lib/evolution.bash"
    local chain='{"chain":{
      "species":{"name":"eevee"},"evolution_details":[],
      "evolves_to":[
        {"species":{"name":"vaporeon"},"evolution_details":[
          {"item":{"name":"water-stone"},"trigger":{"name":"use-item"}}],
         "evolves_to":[]},
        {"species":{"name":"jolteon"},"evolution_details":[
          {"item":{"name":"thunder-stone"},"trigger":{"name":"use-item"}}],
         "evolves_to":[]}]}}'
    run evolution_next_stages "$chain" eevee
    [ "$status" -eq 0 ]
    [ "$(jq 'length' <<< "$output")" = "2" ]
    [ "$(jq -r '.[0].species' <<< "$output")" = "vaporeon" ]
    [ "$(jq -r '.[0].evolution_details[0].item.name' <<< "$output")" = "water-stone" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-encounter-pool.bats -f evolution_`
Expected: FAIL — `lib/evolution.bash` missing.

- [ ] **Step 3: Create `lib/evolution.bash`**

Create `lib/evolution.bash`:

```bash
#!/usr/bin/env bash
# lib/evolution.bash — evolution-loop helpers.
# Depends on pokeapi_get (api.bash) and encounter_pool_load (encounter.bash).

# Look up the tier of a species in a biome's pool.
# Defaults to "common" if the species isn't in any tier.
evolution_tier_lookup() {
    local biome="$1" species="$2"
    if ! command -v encounter_pool_load > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/encounter.bash"
    fi
    local pool
    pool="$(encounter_pool_load "$biome" 2>/dev/null)" || { printf 'common'; return; }
    local tier
    tier="$(jq -r --arg sp "$species" '
        .tiers
        | to_entries
        | map(select(.value | map(.species) | index($sp)))
        | (.[0].key // "common")
    ' <<< "$pool")"
    printf '%s' "$tier"
}

# Given an evolution-chain JSON and a species name, return JSON array of
# {species, evolution_details} for each direct child of that species in the chain.
evolution_next_stages() {
    local chain_json="$1" species="$2"
    jq -c --arg sp "$species" '
        def find($node):
            if $node.species.name == $sp then
                [$node.evolves_to[] | {species: .species.name, evolution_details: .evolution_details}]
            else
                ($node.evolves_to[] | find(.))
            end;
        find(.chain)
    ' <<< "$chain_json"
}
```

- [ ] **Step 4: Source from `pokidle`**

In `pokidle`, after the existing `source "$POKIDLE_REPO_ROOT/lib/encounter.bash"` (around line 27), add:

```bash
# shellcheck source=lib/evolution.bash
source "$POKIDLE_REPO_ROOT/lib/evolution.bash"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats tests/test-encounter-pool.bats -f evolution_`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/evolution.bash pokidle tests/test-encounter-pool.bats
git commit -m "evolution: add tier-lookup and chain-walker helpers"
```

---

## Task 10: Evolution path classification + hard filters

**Files:**
- Modify: `lib/evolution.bash`
- Test: append to `tests/test-encounter-pool.bats` (or create `tests/test-evolution.bats` if file growing too large)

- [ ] **Step 1: Create `tests/test-evolution.bats`**

Create `tests/test-evolution.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    source "$REPO_ROOT/lib/evolution.bash"
}

@test "evolution_check_hard_filters: gender mismatch -> fail" {
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"gender":2}'   # female-only (PokeAPI: 1=male, 2=female, 3=genderless)
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: gender match -> pass" {
    local enc='{"gender":"F","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"gender":2}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -eq 0 ]
}

@test "evolution_check_hard_filters: min_level below threshold -> fail" {
    local enc='{"gender":"M","level":15,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"min_level":20}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: min_happiness below -> fail" {
    local enc='{"gender":"M","level":40,"friendship":150,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"min_happiness":220}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: time_of_day mismatch -> fail" {
    EVOLUTION_TIME_OF_DAY=day  # mock
    export EVOLUTION_TIME_OF_DAY
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"time_of_day":"night"}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: known_move not in list -> fail" {
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":["tackle","growl"]}'
    local evo='{"known_move":{"name":"mimic"}}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: known_move in list -> pass" {
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":["mimic"]}'
    local evo='{"known_move":{"name":"mimic"}}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -eq 0 ]
}

@test "evolution_check_hard_filters: relative_physical_stats atk>def required, atk<=def -> fail" {
    # encounter.stats indices: 0=hp, 1=atk, 2=def, 3=spa, 4=spd, 5=spe
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,15,20,20,20,20],"moves":[]}'
    local evo='{"relative_physical_stats":1}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_path_kind: use-item with item -> item kind" {
    local evo='{"item":{"name":"water-stone"},"trigger":{"name":"use-item"}}'
    [ "$(evolution_path_kind "$evo")" = "item" ]
}

@test "evolution_path_kind: held_item -> item kind" {
    local evo='{"held_item":{"name":"kings-rock"}}'
    [ "$(evolution_path_kind "$evo")" = "item" ]
}

@test "evolution_path_kind: bare level evo -> synthetic" {
    local evo='{"min_level":16,"trigger":{"name":"level-up"}}'
    [ "$(evolution_path_kind "$evo")" = "synthetic" ]
}

@test "evolution_path_item_name extracts name from item or held_item" {
    [ "$(evolution_path_item_name '{"item":{"name":"water-stone"}}')" = "water-stone" ]
    [ "$(evolution_path_item_name '{"held_item":{"name":"kings-rock"}}')" = "kings-rock" ]
    [ "$(evolution_path_item_name '{"min_level":16}')" = "" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-evolution.bats`
Expected: FAIL — helpers missing.

- [ ] **Step 3: Add helpers to `lib/evolution.bash`**

Append to `lib/evolution.bash`:

```bash
# Convert PokeAPI gender code (1=female-only, 2=male-only, ...) to encounter
# gender label. Standard-aware mapping:
#   - PokeAPI evolution_details.gender: 1=Female-only, 2=Male-only, 3=Genderless
# Returns the required label or empty for "no requirement".
_evolution_gender_required() {
    local code="$1"
    case "$code" in
        1) printf 'F' ;;
        2) printf 'M' ;;
        3) printf 'genderless' ;;
        *) printf '' ;;
    esac
}

# Returns "day" or "night" based on local hour. 6:00–17:59 = day; else night.
# Override with EVOLUTION_TIME_OF_DAY env var (used in tests).
_evolution_current_time_of_day() {
    if [[ -n "${EVOLUTION_TIME_OF_DAY:-}" ]]; then
        printf '%s' "$EVOLUTION_TIME_OF_DAY"
        return
    fi
    local h
    h=$(date +%H)
    if (( 10#$h >= 6 && 10#$h < 18 )); then
        printf 'day'
    else
        printf 'night'
    fi
}

# evolution_check_hard_filters <encounter_json> <evo_detail_json>
# Returns 0 if all hard filters pass, non-zero otherwise.
evolution_check_hard_filters() {
    local enc="$1" evo="$2"

    # Gender
    local gcode greq genc
    gcode="$(jq -r '.gender // empty' <<< "$evo")"
    if [[ -n "$gcode" && "$gcode" != "null" ]]; then
        greq="$(_evolution_gender_required "$gcode")"
        if [[ -n "$greq" ]]; then
            genc="$(jq -r '.gender' <<< "$enc")"
            [[ "$greq" == "$genc" ]] || return 1
        fi
    fi

    # min_level
    local ml lvl
    ml="$(jq -r '.min_level // empty' <<< "$evo")"
    if [[ -n "$ml" && "$ml" != "null" ]]; then
        lvl="$(jq -r '.level' <<< "$enc")"
        (( lvl >= ml )) || return 1
    fi

    # min_happiness
    local mh fr
    mh="$(jq -r '.min_happiness // empty' <<< "$evo")"
    if [[ -n "$mh" && "$mh" != "null" ]]; then
        fr="$(jq -r '.friendship' <<< "$enc")"
        (( fr >= mh )) || return 1
    fi

    # time_of_day
    local tod cur
    tod="$(jq -r '.time_of_day // empty' <<< "$evo")"
    if [[ -n "$tod" && "$tod" != "null" && "$tod" != "" ]]; then
        cur="$(_evolution_current_time_of_day)"
        [[ "$tod" == "$cur" ]] || return 1
    fi

    # known_move
    local km
    km="$(jq -r '.known_move.name // empty' <<< "$evo")"
    if [[ -n "$km" && "$km" != "null" ]]; then
        jq -e --arg m "$km" '.moves | index($m)' <<< "$enc" > /dev/null || return 1
    fi

    # known_move_type — encounter.moves are names, not types; we cannot verify.
    # Treat as unverifiable -> hard fail (conservative).
    local kmt
    kmt="$(jq -r '.known_move_type.name // empty' <<< "$evo")"
    [[ -n "$kmt" && "$kmt" != "null" ]] && return 1

    # relative_physical_stats: 1 = atk>def, -1 = def>atk, 0 = atk==def
    local rps atk def
    rps="$(jq -r '.relative_physical_stats // empty' <<< "$evo")"
    if [[ -n "$rps" && "$rps" != "null" ]]; then
        atk="$(jq -r '.stats[1]' <<< "$enc")"
        def="$(jq -r '.stats[2]' <<< "$enc")"
        case "$rps" in
            1)  (( atk > def )) || return 1 ;;
            -1) (( def > atk )) || return 1 ;;
            0)  [[ "$atk" == "$def" ]] || return 1 ;;
        esac
    fi

    return 0
}

# evolution_path_kind <evo_detail_json>
# "item" if the evo requires a consumable item, else "synthetic".
evolution_path_kind() {
    local evo="$1"
    local has_item
    has_item="$(jq -r '.item.name // .held_item.name // empty' <<< "$evo")"
    if [[ -n "$has_item" && "$has_item" != "null" ]]; then
        printf 'item'
    else
        printf 'synthetic'
    fi
}

# evolution_path_item_name <evo_detail_json>
# Returns the item name (kebab-case) or empty.
evolution_path_item_name() {
    local evo="$1"
    jq -r '.item.name // .held_item.name // empty' <<< "$evo"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-evolution.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/evolution.bash tests/test-evolution.bats
git commit -m "evolution: add hard-filter checks and path-kind classifier"
```

---

## Task 11: Viable-path enumeration + uniform pick

**Files:**
- Modify: `lib/evolution.bash`
- Test: `tests/test-evolution.bats`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-evolution.bats`:

```bash
@test "evolution_enumerate_viable_paths: synthetic only when no item" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    local enc='{"gender":"M","level":20,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local stages='[{"species":"linoone","evolution_details":[{"min_level":20,"trigger":{"name":"level-up"}}]}]'
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$status" -eq 0 ]
    [ "$(jq 'length' <<< "$output")" = "1" ]
    [ "$(jq -r '.[0].species' <<< "$output")" = "linoone" ]
    [ "$(jq -r '.[0].kind' <<< "$output")" = "synthetic" ]
}

@test "evolution_enumerate_viable_paths: item path requires item in DB" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);"
    local enc='{"gender":"M","level":20,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local stages='[{"species":"vaporeon","evolution_details":[
        {"item":{"name":"water-stone"},"trigger":{"name":"use-item"}}]}]'
    # No item in DB → no viable path.
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$(jq 'length' <<< "$output")" = "0" ]

    # Add item.
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO item_drops(session_id, encountered_at, item) VALUES (1, 1, 'water-stone');"
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$(jq 'length' <<< "$output")" = "1" ]
    [ "$(jq -r '.[0].kind' <<< "$output")" = "item" ]
    [ "$(jq -r '.[0].item' <<< "$output")" = "water-stone" ]
}

@test "evolution_enumerate_viable_paths: hard filter blocks evo" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local stages='[{"species":"gardevoir","evolution_details":[{"min_level":30,"gender":1}]}]'
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$(jq 'length' <<< "$output")" = "0" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-evolution.bats -f viable_paths`
Expected: FAIL.

- [ ] **Step 3: Add `evolution_enumerate_viable_paths`**

Append to `lib/evolution.bash`:

```bash
# Count item_drops rows for a given item name. Wraps a sqlite query.
_evolution_count_item_drops() {
    local item="$1"
    db_query "SELECT COUNT(*) FROM item_drops WHERE item='${item//\'/\'\'}';"
}

# evolution_enumerate_viable_paths <encounter_json> <next_stages_json>
# Emits JSON array of viable paths: {species, kind, item?, evo}.
evolution_enumerate_viable_paths() {
    local enc="$1" stages="$2"
    if ! command -v db_query > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/db.bash"
    fi
    local out='[]'
    local n
    n="$(jq 'length' <<< "$stages")"
    local i
    for (( i=0; i<n; i++ )); do
        local stage
        stage="$(jq -c ".[$i]" <<< "$stages")"
        local species
        species="$(jq -r '.species' <<< "$stage")"
        local evos m j
        m="$(jq '.evolution_details | length' <<< "$stage")"
        for (( j=0; j<m; j++ )); do
            local evo
            evo="$(jq -c ".evolution_details[$j]" <<< "$stage")"
            evolution_check_hard_filters "$enc" "$evo" || continue
            local kind item
            kind="$(evolution_path_kind "$evo")"
            if [[ "$kind" == "item" ]]; then
                item="$(evolution_path_item_name "$evo")"
                local cnt
                cnt="$(_evolution_count_item_drops "$item")"
                (( cnt > 0 )) || continue
                out="$(jq -c --arg sp "$species" --arg item "$item" --argjson e "$evo" \
                    '. + [{species:$sp, kind:"item", item:$item, evo:$e}]' <<< "$out")"
            else
                out="$(jq -c --arg sp "$species" --argjson e "$evo" \
                    '. + [{species:$sp, kind:"synthetic", evo:$e}]' <<< "$out")"
            fi
        done
    done
    printf '%s' "$out"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-evolution.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/evolution.bash tests/test-evolution.bats
git commit -m "evolution: enumerate viable evolution paths"
```

---

## Task 12: Apply evolution (DB write + stats recompute)

**Files:**
- Modify: `lib/evolution.bash`
- Test: `tests/test-evolution.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-evolution.bats`:

```bash
@test "evolution_apply: synthetic path updates encounter species/dex/sprite/stats" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    load_lib encounter
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship,
            iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe)
            VALUES (1, 1700000000, 'zigzagoon', 263, 20, 'hardy', 'pickup', 0, 'M', 0, '[]',
                70, 10,10,10,10,10,10, 0,0,0,0,0,0);"

    pokeapi_get() {
        case "$1" in
            pokemon/linoone)
                printf '%s' '{"id":264,"sprites":{"front_default":"linoone.png","front_shiny":""},
                  "stats":[
                    {"base_stat":78,"stat":{"name":"hp"}},
                    {"base_stat":70,"stat":{"name":"attack"}},
                    {"base_stat":61,"stat":{"name":"defense"}},
                    {"base_stat":50,"stat":{"name":"special-attack"}},
                    {"base_stat":61,"stat":{"name":"special-defense"}},
                    {"base_stat":100,"stat":{"name":"speed"}}]}'
                ;;
            nature/hardy) printf '{"increased_stat":null,"decreased_stat":null}' ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get

    local path='{"species":"linoone","kind":"synthetic","evo":{"min_level":20}}'
    run evolution_apply 1 "$path"
    [ "$status" -eq 0 ]
    local row
    row="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT species||','||dex_id||','||sprite_path FROM encounters WHERE id=1;")"
    [ "$row" = "linoone,264,linoone.png" ]
}

@test "evolution_apply: item path consumes one item_drops row" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    load_lib encounter
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship,
            iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe)
            VALUES (1, 1700000000, 'eevee', 133, 20, 'hardy', 'run-away', 0, 'M', 0, '[]',
                70, 10,10,10,10,10,10, 0,0,0,0,0,0);
        INSERT INTO item_drops(session_id, encountered_at, item) VALUES
            (1, 1, 'water-stone'),
            (1, 2, 'water-stone');"

    pokeapi_get() {
        case "$1" in
            pokemon/vaporeon)
                printf '%s' '{"id":134,"sprites":{"front_default":"vap.png","front_shiny":""},
                  "stats":[
                    {"base_stat":130,"stat":{"name":"hp"}},
                    {"base_stat":65,"stat":{"name":"attack"}},
                    {"base_stat":60,"stat":{"name":"defense"}},
                    {"base_stat":110,"stat":{"name":"special-attack"}},
                    {"base_stat":95,"stat":{"name":"special-defense"}},
                    {"base_stat":65,"stat":{"name":"speed"}}]}'
                ;;
            nature/hardy) printf '{"increased_stat":null,"decreased_stat":null}' ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get

    local path='{"species":"vaporeon","kind":"item","item":"water-stone","evo":{}}'
    evolution_apply 1 "$path"
    local n
    n="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM item_drops WHERE item='water-stone';")"
    [ "$n" = "1" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-evolution.bats -f evolution_apply`
Expected: FAIL.

- [ ] **Step 3: Add `evolution_apply`**

Append to `lib/evolution.bash`:

```bash
# evolution_apply <encounter_id> <path_json>
# Mutates the encounter row to the evolved species. Consumes one item_drops
# row if path.kind == "item".
evolution_apply() {
    local enc_id="$1" path="$2"
    local kind species item
    kind="$(jq -r '.kind' <<< "$path")"
    species="$(jq -r '.species' <<< "$path")"

    if [[ "$kind" == "item" ]]; then
        item="$(jq -r '.item' <<< "$path")"
        db_delete_one_item_drop "$item" > /dev/null
    fi

    # Re-fetch the encounter row to compose stat inputs.
    local enc_row
    enc_row="$(db_query_json "SELECT * FROM encounters WHERE id=$enc_id;" | jq -c '.[0]')"
    local nature level ivs evs
    nature="$(jq -r '.nature' <<< "$enc_row")"
    level="$(jq -r '.level' <<< "$enc_row")"
    ivs="$(jq -r '"\(.iv_hp) \(.iv_atk) \(.iv_def) \(.iv_spa) \(.iv_spd) \(.iv_spe)"' <<< "$enc_row")"
    evs="$(jq -r '"\(.ev_hp) \(.ev_atk) \(.ev_def) \(.ev_spa) \(.ev_spd) \(.ev_spe)"' <<< "$enc_row")"
    local shiny
    shiny="$(jq -r '.shiny' <<< "$enc_row")"

    local poke base_stats sprite mods stats dex_id
    poke="$(pokeapi_get "pokemon/$species")" || return 1
    dex_id="$(jq -r '.id' <<< "$poke")"
    if [[ "$shiny" == "1" ]]; then
        sprite="$(jq -r '.sprites.front_shiny // .sprites.front_default // ""' <<< "$poke")"
    else
        sprite="$(jq -r '.sprites.front_default // ""' <<< "$poke")"
    fi
    base_stats="$(jq -c '.stats' <<< "$poke")"
    mods="$(encounter_nature_mods "$nature")" || return 1
    stats="$(encounter_compute_all_stats "$base_stats" "$ivs" "$evs" "$level" "$mods")" || return 1

    db_update_encounter_evolved "$enc_id" "$species" "$dex_id" "$sprite" "$stats"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-evolution.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/evolution.bash tests/test-evolution.bats
git commit -m "evolution: apply chosen path with stats recompute and item consume"
```

---

## Task 13: `pokidle_tick_evolve`

**Files:**
- Modify: `pokidle`
- Test: `tests/test-evolution.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-evolution.bats`:

```bash
@test "pokidle tick evolve --json: synthetic candidate evolves on tier-pass" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/pcache.$$"
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/pcfg.$$"
    mkdir -p "$POKIDLE_CACHE_DIR/pools" "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR POKIDLE_CONFIG_DIR

    cat > "$POKIDLE_CACHE_DIR/pools/plain.json" <<'EOF'
{"biome":"plain","schema":2,"tiers":{
  "common":[{"species":"zigzagoon","min":3,"max":5}],
  "uncommon":[],"rare":[],"very_rare":[]
}}
EOF

    local mon_ts now
    mon_ts="$(date -d "$(date -d 'this monday' +%F) 00:00:00" +%s 2>/dev/null \
              || date -v-mon -v0H -v0M -v0S +%s)"
    now=$((mon_ts + 86400))
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', $mon_ts);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship,
            iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe)
            VALUES (1, $now, 'zigzagoon', 263, 5, 'hardy', 'pickup', 0, 'M', 0, '[]',
                70, 10,10,10,10,10,10, 0,0,0,0,0,0);"

    # Caching pokeapi: pre-write expected responses.
    POKEAPI_CACHE_DIR="$BATS_TMPDIR/papi.$$"
    export POKEAPI_CACHE_DIR
    mkdir -p "$POKEAPI_CACHE_DIR"
    cat > "$POKEAPI_CACHE_DIR/pokemon-species/zigzagoon.json" <<'EOF'
{"evolution_chain":{"url":"https://x/evolution-chain/64/"},"base_happiness":70}
EOF
    mkdir -p "$POKEAPI_CACHE_DIR/evolution-chain"
    cat > "$POKEAPI_CACHE_DIR/evolution-chain/64.json" <<'EOF'
{"chain":{"species":{"name":"zigzagoon"},"evolution_details":[],
  "evolves_to":[{"species":{"name":"linoone"},"evolution_details":[
    {"min_level":20,"trigger":{"name":"level-up"}}],"evolves_to":[]}]}}
EOF
    cat > "$POKEAPI_CACHE_DIR/pokemon/linoone.json" <<'EOF'
{"id":264,"sprites":{"front_default":"lin.png","front_shiny":""},
  "stats":[
    {"base_stat":78,"stat":{"name":"hp"}},
    {"base_stat":70,"stat":{"name":"attack"}},
    {"base_stat":61,"stat":{"name":"defense"}},
    {"base_stat":50,"stat":{"name":"special-attack"}},
    {"base_stat":61,"stat":{"name":"special-defense"}},
    {"base_stat":100,"stat":{"name":"speed"}}]}
EOF
    mkdir -p "$POKEAPI_CACHE_DIR/nature"
    cat > "$POKEAPI_CACHE_DIR/nature/hardy.json" <<'EOF'
{"increased_stat":null,"decreased_stat":null}
EOF

    # zigzagoon level 5 -> linoone via synthetic (min_level NOT met → blocked).
    # Bump level to 20 first via direct sqlite UPDATE so synthetic path passes
    # min_level hard filter.
    sqlite3 "$POKIDLE_DB_PATH" "UPDATE encounters SET level=20 WHERE id=1;"

    local i hit=0 out
    for i in {1..50}; do
        out="$("$REPO_ROOT/pokidle" tick evolve --dry-run --no-notify --json 2>/dev/null)"
        local n="$(jq '.evolved | length' <<< "$out")"
        if (( n > 0 )); then
            hit=1
            [ "$(jq -r '.evolved[0].from' <<< "$out")" = "zigzagoon" ]
            [ "$(jq -r '.evolved[0].to'   <<< "$out")" = "linoone" ]
            break
        fi
    done
    [ "$hit" = "1" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/test-evolution.bats -f "tick evolve"`
Expected: FAIL — `tick evolve` unknown.

- [ ] **Step 3: Implement `pokidle_tick_evolve`**

Add to `pokidle` after `pokidle_tick_friendship`:

```bash
pokidle_tick_evolve() {
    local dry_run=0 no_notify=0 emit_json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   dry_run=1; shift ;;
            --no-notify) no_notify=1; shift ;;
            --json)      emit_json=1; shift ;;
            *) printf 'tick evolve: unknown flag %s\n' "$1" >&2; return 2 ;;
        esac
    done

    db_init

    local active sid biome
    active="$(db_active_biome_session)"
    [[ -n "$active" ]] || { printf 'tick evolve: no active biome session\n' >&2; return 1; }
    IFS=$'\t' read -r sid biome _ <<< "$active"

    local rows
    rows="$(db_list_current_week_encounters)"
    local evolved='[]'
    local n
    n="$(jq 'length' <<< "$rows")"
    local i
    for (( i=0; i<n; i++ )); do
        local r enc_id species enc_obj
        r="$(jq -c ".[$i]" <<< "$rows")"
        enc_id="$(jq -r '.id' <<< "$r")"
        species="$(jq -r '.species' <<< "$r")"

        # Build the encounter object the evolution checker expects.
        enc_obj="$(jq -c '{
            gender, level, friendship,
            stats: [.stat_hp, .stat_atk, .stat_def, .stat_spa, .stat_spd, .stat_spe],
            moves: (.moves_json | fromjson)
        }' <<< "$r")"

        local spec chain_url chain_id chain stages
        spec="$(pokeapi_get "pokemon-species/$species" 2>/dev/null)" || continue
        chain_url="$(jq -r '.evolution_chain.url' <<< "$spec")"
        [[ -z "$chain_url" || "$chain_url" == "null" ]] && continue
        chain_id="$(basename -- "${chain_url%/}")"
        chain="$(pokeapi_get "evolution-chain/$chain_id" 2>/dev/null)" || continue
        stages="$(evolution_next_stages "$chain" "$species")"
        [[ "$(jq 'length' <<< "$stages")" == "0" ]] && continue

        local viable
        viable="$(evolution_enumerate_viable_paths "$enc_obj" "$stages")"
        local v_n
        v_n="$(jq 'length' <<< "$viable")"
        (( v_n > 0 )) || continue

        local tier chance
        tier="$(evolution_tier_lookup "$biome" "$species")"
        case "$tier" in
            common)    chance=25 ;;
            uncommon)  chance=15 ;;
            rare)      chance=8 ;;
            very_rare) chance=3 ;;
            *)         chance=25 ;;
        esac
        (( RANDOM % 100 < chance )) || continue

        local idx pick new_species kind
        idx=$(( RANDOM % v_n ))
        pick="$(jq -c ".[$idx]" <<< "$viable")"
        new_species="$(jq -r '.species' <<< "$pick")"
        kind="$(jq -r '.kind' <<< "$pick")"

        if (( dry_run == 0 )); then
            evolution_apply "$enc_id" "$pick" || continue
        fi
        evolved="$(jq -c \
            --argjson id "$enc_id" --arg from "$species" --arg to "$new_species" --arg kind "$kind" \
            '. + [{id:$id, from:$from, to:$to, kind:$kind}]' <<< "$evolved")"
    done

    if (( emit_json )); then
        jq -n --argjson e "$evolved" '{evolved: $e}'
    fi
}
```

Wire dispatch in `pokidle_tick`'s case (with the other new arms):

```bash
        evolve)
            pokidle_tick_evolve "$@"
            ;;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-evolution.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pokidle tests/test-evolution.bats
git commit -m "pokidle: add tick evolve subcommand"
```

---

## Task 14: Daemon timers + biome rotation hook

**Files:**
- Modify: `pokidle` — `pokidle_daemon` and `pokidle_switch_biome`
- Test: extend `tests/test-daemon.bats` if it has fast-mode tests; otherwise smoke test only.

- [ ] **Step 1: Read current daemon body**

Open `pokidle:90-160` (`pokidle_daemon`). Identify:
- Two existing `last_*_tick_target` restore blocks (level/item).
- Main loop's three `if (( now >= next_X ))` blocks.
- Biome rotation block at top of the loop body.

- [ ] **Step 2: Add level + friendship timers and evolution hook to `pokidle_daemon`**

In `pokidle_daemon`, after the existing `next_item` restore block (around line 126), add:

```bash
    local next_level next_friendship
    next_level="$(db_state_get last_level_tick_target)"
    next_friendship="$(db_state_get last_friendship_tick_target)"
    if [[ -z "$next_level" || "$next_level" -le "$now" ]]; then
        next_level="$(_pokidle_next_tick_target "$now" "${POKIDLE_LEVEL_INTERVAL:-3600}")"
        db_state_set last_level_tick_target "$next_level" || \
            printf 'daemon: persist last_level_tick_target failed (continuing)\n' >&2
    fi
    if [[ -z "$next_friendship" || "$next_friendship" -le "$now" ]]; then
        next_friendship="$(_pokidle_next_tick_target "$now" "${POKIDLE_FRIENDSHIP_INTERVAL:-1800}")"
        db_state_set last_friendship_tick_target "$next_friendship" || \
            printf 'daemon: persist last_friendship_tick_target failed (continuing)\n' >&2
    fi
```

Inside the main `while :;` loop, after the biome-rotation block (which already calls `db_close_biome_session` + `db_open_biome_session` + `_pokidle_announce_biome`), insert an evolution call:

```bash
        if _pokidle_should_rotate_biome "$biome_started_at" "$now"; then
            db_close_biome_session "$sid" "$now"
            biome="$(biome_pick_random_excluding "$biome")"
            biome_started_at="$now"
            sid="$(db_open_biome_session "$biome" "$biome_started_at")"
            _pokidle_announce_biome "$biome"
            if [[ "${POKIDLE_EVOLVE_ENABLED:-1}" == "1" ]]; then
                pokidle_tick_evolve --no-notify --json > /dev/null \
                    || printf 'daemon: evolve tick failed (continuing)\n' >&2
            fi
        fi
```

After the existing `next_item` firing block, add:

```bash
        if (( now >= next_level )); then
            pokidle_tick_level --no-notify --json > /dev/null \
                || printf 'daemon: level tick failed (continuing)\n' >&2
            next_level="$(_pokidle_next_tick_target "$now" "${POKIDLE_LEVEL_INTERVAL:-3600}")"
            db_state_set last_level_tick_target "$next_level" || \
                printf 'daemon: persist last_level_tick_target failed (continuing)\n' >&2
        fi
        if (( now >= next_friendship )); then
            pokidle_tick_friendship --no-notify --json > /dev/null \
                || printf 'daemon: friendship tick failed (continuing)\n' >&2
            next_friendship="$(_pokidle_next_tick_target "$now" "${POKIDLE_FRIENDSHIP_INTERVAL:-1800}")"
            db_state_set last_friendship_tick_target "$next_friendship" || \
                printf 'daemon: persist last_friendship_tick_target failed (continuing)\n' >&2
        fi
```

Update the `next_event` calculation lower in the loop:

```bash
        local biome_end=$((biome_started_at + ${POKIDLE_BIOME_HOURS:-3} * 3600))
        local next_event=$next_pokemon
        (( next_item < next_event )) && next_event=$next_item
        (( next_level < next_event )) && next_event=$next_level
        (( next_friendship < next_event )) && next_event=$next_friendship
        (( biome_end < next_event )) && next_event="$biome_end"
```

- [ ] **Step 3: Update `pokidle_switch_biome` to fire evolution loop**

In `pokidle_switch_biome` (locate by name, ~line 478), after `db_open_biome_session ... new_sid` and before the `printf 'switched...'`, add:

```bash
    if [[ "${POKIDLE_EVOLVE_ENABLED:-1}" == "1" ]]; then
        pokidle_tick_evolve --no-notify --json > /dev/null || true
    fi
```

- [ ] **Step 4: Smoke test**

Run: `bats tests/`
Expected: PASS — no test exercises the daemon in real-time, but existing CLI tests should still pass.

Run a manual quick check:

```bash
./pokidle switch-biome cave > /dev/null
./pokidle switch-biome plain > /dev/null
```

The second invocation triggers a closed session + new session + evolution loop. It should not error.

- [ ] **Step 5: Commit**

```bash
git add pokidle
git commit -m "pokidle: wire level/friendship timers + evolve on biome rotation"
```

---

## Task 15: Final verification

**Files:** none (read-only)

- [ ] **Step 1: Run the full bats suite**

Run: `bats tests/`
Expected: every test passes.

- [ ] **Step 2: shellcheck**

Run: `shellcheck lib/db.bash lib/encounter.bash lib/evolution.bash pokidle 2>&1 | head -50`
Expected: no NEW warnings beyond pre-existing ones (the redesign of pool helpers introduced none; this should be the same).

- [ ] **Step 3: Manual end-to-end smoke**

```bash
./pokidle switch-biome graveyard > /dev/null
./pokidle tick pokemon --no-notify --json > /dev/null
./pokidle tick level --no-notify --json
./pokidle tick friendship --no-notify --json
./pokidle tick evolve --no-notify --json
```

Each command should exit 0. The evolve tick may legitimately produce
`{"evolved": []}` if no candidate's tier roll passes — re-run a few times.

- [ ] **Step 4: Commit any fixes if needed**

If steps 1–3 surfaced issues, fix and commit. Otherwise skip.

---

## Self-review notes

**Spec coverage:**
- Schema migration → Task 1.
- Friendship at insert → Tasks 2, 3, 4.
- Current-week candidate window → Task 5.
- DB update wrappers → Task 6.
- Level loop core + CLI → Task 7.
- Friendship loop core + CLI → Task 8.
- Evolution helpers (tier lookup, chain walker) → Task 9.
- Evolution hard filters + path classification → Tasks 10.
- Viable-path enumeration → Task 11.
- Apply evolution + stats recompute + item consume → Task 12.
- Evolution CLI + daemon hook + switch-biome hook → Tasks 13, 14.
- Verification → Task 15.

**Type/name consistency:**
- `db_update_encounter_*`, `db_delete_one_item_drop`, `db_list_current_week_encounters` named consistently and used in Tasks 7/8/12 as defined in Tasks 5/6.
- `evolution_*` helpers all defined in Task 9–12 and consumed in Task 13.
- `pokidle_tick_level`/`_friendship`/`_evolve` all wired into the same `pokidle_tick` dispatch case.

**Placeholder scan:** every step contains the actual bash to add or replace. No TODO/TBD.
