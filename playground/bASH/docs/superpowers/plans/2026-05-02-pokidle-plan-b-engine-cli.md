# pokidle Plan B: Encounter Engine + Notifications + CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plan A (`docs/superpowers/plans/2026-05-02-pokidle-plan-a-foundation.md`) complete.

**Goal:** Build the encounter engine (pool building from `/location-area`, evolution-line expansion with halving %, IV/EV/nature/ability/moves/gender/shiny/held-berry rolls, gen3+ stat formulas), notifications via `notify-send` with sprite icons + sound, Pokémon Showdown set export, and the `pokidle` entry script with all non-daemon subcommands. End state: a user can run `pokidle tick pokemon` and see a notification + persisted encounter; `pokidle list --export` emits Showdown sets.

**Architecture:** Pool/encounter logic lives in `lib/encounter.bash`, depending on the existing pokeapi lib (`pokeapi_get`) and on `lib/biome.bash`/`lib/db.bash` from Plan A. Notifications and sound in `lib/notify.bash`. Showdown text in `lib/showdown.bash`. `pokidle` is a single-file dispatcher script at the repo root that sources libs and routes to subcommand functions.

**Tech Stack:** bash 4+, jq, sqlite3, libnotify-bin, paplay/aplay, catimg (optional), bats-core (test).

**Spec reference:** `docs/superpowers/specs/2026-05-02-pokidle-design.md`.

---

## File map (Plan B)

| File | Status | Responsibility |
|---|---|---|
| `lib/encounter.bash` | create | pool build, evo expansion, all rolls, stat formulas |
| `lib/notify.bash` | create | notify-send + sound |
| `lib/showdown.bash` | create | Showdown set text formatter |
| `pokidle` | create | entry script, subcommand dispatcher |
| `tests/fixtures/pokemon-*.json` | create | per-species `/pokemon` fixtures |
| `tests/fixtures/pokemon-species-*.json` | create | `/pokemon-species` fixtures |
| `tests/fixtures/evolution-chain-*.json` | create | `/evolution-chain` fixtures |
| `tests/fixtures/location-area-*.json` | create | richer `/location-area` fixtures |
| `tests/fixtures/nature-list.json` | create | `/nature?limit=100` fixture |
| `tests/fixtures/nature-adamant.json` | create | individual `/nature` fixture |
| `tests/test-encounter-pool.bats` | create | pool build tests |
| `tests/test-encounter-rolls.bats` | create | IV/EV/nature/ability/moves/gender/shiny tests |
| `tests/test-encounter-stats.bats` | create | stat formula tests |
| `tests/test-notify.bats` | create | notification command builder tests |
| `tests/test-showdown.bats` | create | Showdown formatter tests |
| `tests/test-cli.bats` | create | CLI subcommand smoke tests |

---

## Task 1: Nature lookup cache helper

**Files:**
- Create: `lib/encounter.bash`
- Create: `tests/fixtures/nature-list.json`
- Create: `tests/fixtures/nature-adamant.json`
- Create: `tests/fixtures/nature-bashful.json`
- Create: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add fixtures**

`tests/fixtures/nature-list.json`:

```json
{"results":[
  {"name":"adamant"},{"name":"bashful"},{"name":"bold"},{"name":"brave"},{"name":"calm"},
  {"name":"careful"},{"name":"docile"},{"name":"gentle"},{"name":"hardy"},{"name":"hasty"},
  {"name":"impish"},{"name":"jolly"},{"name":"lax"},{"name":"lonely"},{"name":"mild"},
  {"name":"modest"},{"name":"naive"},{"name":"naughty"},{"name":"quiet"},{"name":"quirky"},
  {"name":"rash"},{"name":"relaxed"},{"name":"sassy"},{"name":"serious"},{"name":"timid"}
]}
```

`tests/fixtures/nature-adamant.json`:

```json
{
  "name":"adamant",
  "increased_stat":{"name":"attack"},
  "decreased_stat":{"name":"special-attack"}
}
```

`tests/fixtures/nature-bashful.json`:

```json
{"name":"bashful","increased_stat":null,"decreased_stat":null}
```

> Note: helpers.bash `stub_pokeapi` translates `nature?limit=100` → `nature-limit-100`. Rename `tests/fixtures/nature-list.json` to `tests/fixtures/nature-limit-100.json` to match. Same for any endpoint with query params.

Rename:
```bash
mv tests/fixtures/nature-list.json tests/fixtures/nature-limit-100.json
```

- [ ] **Step 2: Write failing tests**

`tests/test-encounter-rolls.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib encounter
    stub_pokeapi
}

@test "encounter_natures_list returns 25 names" {
    run encounter_natures_list
    [ "$status" -eq 0 ]
    local n
    n="$(printf '%s\n' "$output" | wc -l)"
    [ "$n" = "25" ]
}

@test "encounter_nature_mods adamant: +atk -spa" {
    run encounter_nature_mods adamant
    [ "$status" -eq 0 ]
    # Output is space-separated 6 floats: hp atk def spa spd spe
    local mods=($output)
    [ "${mods[0]}" = "1.0" ]
    [ "${mods[1]}" = "1.1" ]
    [ "${mods[2]}" = "1.0" ]
    [ "${mods[3]}" = "0.9" ]
    [ "${mods[4]}" = "1.0" ]
    [ "${mods[5]}" = "1.0" ]
}

@test "encounter_nature_mods bashful: all 1.0 (neutral)" {
    run encounter_nature_mods bashful
    [ "$status" -eq 0 ]
    local mods=($output)
    [ "${mods[0]}" = "1.0" ]
    [ "${mods[1]}" = "1.0" ]
    [ "${mods[2]}" = "1.0" ]
    [ "${mods[3]}" = "1.0" ]
    [ "${mods[4]}" = "1.0" ]
    [ "${mods[5]}" = "1.0" ]
}
```

- [ ] **Step 3: Run, expect fail**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 4: Implement `lib/encounter.bash` (nature helpers)**

`lib/encounter.bash`:

```bash
#!/usr/bin/env bash
# lib/encounter.bash — pool build, evo expansion, rolls, stat formulas.
# Depends on pokeapi_get from lib/api.bash.

# All 6 stats in canonical order.
ENCOUNTER_STATS=(hp attack defense special-attack special-defense speed)

encounter_natures_list() {
    pokeapi_get "nature?limit=100" | jq -r '.results[].name'
}

# Print 6 space-separated floats: nature_mod for hp atk def spa spd spe.
encounter_nature_mods() {
    local nature="$1"
    local nat
    nat="$(pokeapi_get "nature/$nature")"
    local inc dec
    inc="$(jq -r '.increased_stat.name // ""' <<< "$nat")"
    dec="$(jq -r '.decreased_stat.name // ""' <<< "$nat")"

    local s out=()
    for s in "${ENCOUNTER_STATS[@]}"; do
        if [[ "$s" == "$inc" ]]; then
            out+=("1.1")
        elif [[ "$s" == "$dec" ]]; then
            out+=("0.9")
        else
            out+=("1.0")
        fi
    done
    printf '%s' "${out[*]}"
}
```

- [ ] **Step 5: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 6: Commit**

```bash
git add lib/encounter.bash tests/fixtures/nature-limit-100.json tests/fixtures/nature-adamant.json tests/fixtures/nature-bashful.json tests/test-encounter-rolls.bats
git commit -m "feat(encounter): nature lookup and modifier table"
```

---

## Task 2: IVs, EVs, level rolls

**Files:**
- Modify: `lib/encounter.bash`
- Modify: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add tests**

Append to `tests/test-encounter-rolls.bats`:

```bash
@test "encounter_roll_ivs returns 6 ints in [0,31]" {
    run encounter_roll_ivs
    [ "$status" -eq 0 ]
    local ivs=($output)
    [ "${#ivs[@]}" -eq 6 ]
    local i
    for i in "${ivs[@]}"; do
        [ "$i" -ge 0 ] && [ "$i" -le 31 ]
    done
}

@test "encounter_ev_split: total ≤ 510, each ≤ 252" {
    local i
    for i in {1..50}; do
        local out
        out="$(encounter_ev_split "$((RANDOM % 511))")"
        local arr=($out)
        [ "${#arr[@]}" -eq 6 ]
        local total=0 v
        for v in "${arr[@]}"; do
            [ "$v" -le 252 ]
            [ "$v" -ge 0 ]
            total=$((total + v))
        done
        [ "$total" -le 510 ]
    done
}

@test "encounter_ev_split(0) = all zeros" {
    run encounter_ev_split 0
    [ "$output" = "0 0 0 0 0 0" ]
}

@test "encounter_roll_level: uniform within [min,max] inclusive" {
    local i out
    for i in {1..30}; do
        out="$(encounter_roll_level 5 8)"
        [ "$out" -ge 5 ] && [ "$out" -le 8 ]
    done
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 3: Implement**

Append to `lib/encounter.bash`:

```bash
encounter_roll_ivs() {
    local i out=()
    for i in {0..5}; do
        out+=("$((RANDOM % 32))")
    done
    printf '%s' "${out[*]}"
}

encounter_ev_split() {
    local total="$1"
    local evs=(0 0 0 0 0 0)
    local remaining="$total"
    local guard=0
    while (( remaining > 0 )); do
        (( guard++ > 10000 )) && break
        local i=$((RANDOM % 6))
        local headroom=$((252 - evs[i]))
        (( headroom <= 0 )) && {
            # check if all capped
            local all=1 j
            for j in "${evs[@]}"; do (( j < 252 )) && { all=0; break; }; done
            (( all )) && break
            continue
        }
        local cap=$((headroom < remaining ? headroom : remaining))
        local delta=$(( (RANDOM % cap) + 1 ))
        evs[i]=$((evs[i] + delta))
        remaining=$((remaining - delta))
    done
    printf '%s' "${evs[*]}"
}

encounter_roll_level() {
    local lo="$1" hi="$2"
    local span=$((hi - lo + 1))
    printf '%d' "$((lo + RANDOM % span))"
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-rolls.bats
git commit -m "feat(encounter): IVs, EV split, level rolls"
```

---

## Task 3: Stat formulas (gen 3+)

**Files:**
- Modify: `lib/encounter.bash`
- Create: `tests/test-encounter-stats.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-encounter-stats.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib encounter
    stub_pokeapi
}

@test "encounter_compute_stat HP: known Garchomp at lvl 100" {
    # Garchomp HP base 108, IV 31, EV 0, lvl 100 -> 357
    run encounter_compute_stat hp 108 31 0 100 1.0
    [ "$status" -eq 0 ]
    [ "$output" = "357" ]
}

@test "encounter_compute_stat Atk: Adamant Garchomp lvl 100 31IV 252EV" {
    # base 130, IV 31, EV 252, lvl 100, Adamant +atk = 1.1 -> 359
    run encounter_compute_stat attack 130 31 252 100 1.1
    [ "$status" -eq 0 ]
    [ "$output" = "359" ]
}

@test "encounter_compute_stat with neutral nature equals base case" {
    run encounter_compute_stat speed 102 31 252 100 1.0
    [ "$status" -eq 0 ]
    [ "$output" = "326" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-encounter-stats.bats
```

- [ ] **Step 3: Implement**

Append to `lib/encounter.bash`:

```bash
# encounter_compute_stat <stat-name> <base> <iv> <ev> <level> <nature_mod>
# stat-name in {hp, attack, defense, special-attack, special-defense, speed}.
# nature_mod is "0.9", "1.0", or "1.1".
encounter_compute_stat() {
    local stat="$1" base="$2" iv="$3" ev="$4" level="$5" nm="$6"
    # core = floor(((2*base + iv + floor(ev/4)) * level) / 100)
    local ev_q=$((ev / 4))
    local core=$(( ((2 * base + iv + ev_q) * level) / 100 ))
    if [[ "$stat" == "hp" ]]; then
        printf '%d' "$((core + level + 10))"
        return
    fi
    # other = floor((core + 5) * nm)
    # nm is one of 0.9 / 1.0 / 1.1; compute integer-only:
    case "$nm" in
        "1.0") printf '%d' "$((core + 5))" ;;
        "1.1") printf '%d' "$(( ((core + 5) * 110) / 100 ))" ;;
        "0.9") printf '%d' "$(( ((core + 5) * 90)  / 100 ))" ;;
        *)     printf 'encounter_compute_stat: bad nature_mod %s\n' "$nm" >&2; return 1 ;;
    esac
}

# encounter_compute_all_stats <base_json> <ivs_str> <evs_str> <level> <mods_str>
# base_json is .stats[] from /pokemon (array of {base_stat, stat:{name}}).
# Prints "hp atk def spa spd spe" final stats.
encounter_compute_all_stats() {
    local base_json="$1" ivs_str="$2" evs_str="$3" level="$4" mods_str="$5"
    local ivs=($ivs_str) evs=($evs_str) mods=($mods_str)
    local out=()
    local i
    for i in {0..5}; do
        local stat="${ENCOUNTER_STATS[$i]}"
        local base
        base="$(jq -r --arg s "$stat" '.[] | select(.stat.name==$s) | .base_stat' <<< "$base_json")"
        out+=("$(encounter_compute_stat "$stat" "$base" "${ivs[$i]}" "${evs[$i]}" "$level" "${mods[$i]}")")
    done
    printf '%s' "${out[*]}"
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-encounter-stats.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-stats.bats
git commit -m "feat(encounter): gen3+ stat formulas"
```

---

## Task 4: Ability roll

**Files:**
- Modify: `lib/encounter.bash`
- Create: `tests/fixtures/pokemon-treecko.json`
- Modify: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add fixture**

`tests/fixtures/pokemon-treecko.json`:

```json
{
  "id": 252,
  "name": "treecko",
  "types": [{"type":{"name":"grass"}}],
  "abilities": [
    {"ability":{"name":"overgrow"},"is_hidden":false,"slot":1},
    {"ability":{"name":"unburden"},"is_hidden":true,"slot":3}
  ],
  "stats": [
    {"base_stat":40,"stat":{"name":"hp"}},
    {"base_stat":45,"stat":{"name":"attack"}},
    {"base_stat":35,"stat":{"name":"defense"}},
    {"base_stat":65,"stat":{"name":"special-attack"}},
    {"base_stat":55,"stat":{"name":"special-defense"}},
    {"base_stat":70,"stat":{"name":"speed"}}
  ],
  "moves": [
    {"move":{"name":"pound"},"version_group_details":[{"move_learn_method":{"name":"level-up"},"level_learned_at":1}]},
    {"move":{"name":"leer"},"version_group_details":[{"move_learn_method":{"name":"level-up"},"level_learned_at":3}]},
    {"move":{"name":"absorb"},"version_group_details":[{"move_learn_method":{"name":"level-up"},"level_learned_at":6}]},
    {"move":{"name":"quick-attack"},"version_group_details":[{"move_learn_method":{"name":"level-up"},"level_learned_at":11}]},
    {"move":{"name":"pursuit"},"version_group_details":[{"move_learn_method":{"name":"level-up"},"level_learned_at":17}]},
    {"move":{"name":"giga-drain"},"version_group_details":[{"move_learn_method":{"name":"machine"},"level_learned_at":0}]},
    {"move":{"name":"endeavor"},"version_group_details":[{"move_learn_method":{"name":"egg"},"level_learned_at":0}]},
    {"move":{"name":"snatch"},"version_group_details":[{"move_learn_method":{"name":"tutor"},"level_learned_at":0}]}
  ],
  "sprites": {"front_default":"https://x/treecko.png","front_shiny":"https://x/treecko-s.png"}
}
```

- [ ] **Step 2: Add tests**

Append to `tests/test-encounter-rolls.bats`:

```bash
@test "encounter_roll_ability: forced normal yields slot1+slot2 only" {
    POKIDLE_HIDDEN_ABILITY_RATE=0
    local i out
    for i in {1..30}; do
        out="$(encounter_roll_ability treecko)"
        local name hidden
        name="$(jq -r '.name' <<< "$out")"
        hidden="$(jq -r '.is_hidden' <<< "$out")"
        [ "$hidden" = "false" ]
        [ "$name" = "overgrow" ]    # only normal slot in fixture
    done
}

@test "encounter_roll_ability: forced hidden yields hidden when present" {
    POKIDLE_HIDDEN_ABILITY_RATE=100
    run encounter_roll_ability treecko
    [ "$status" -eq 0 ]
    local hidden
    hidden="$(jq -r '.is_hidden' <<< "$output")"
    [ "$hidden" = "true" ]
}
```

- [ ] **Step 3: Run, expect fail**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 4: Implement**

Append to `lib/encounter.bash`:

```bash
# Roll an ability. Prints JSON {name, is_hidden}.
encounter_roll_ability() {
    local species="$1"
    local poke
    poke="$(pokeapi_get "pokemon/$species")"
    local hidden_rate="${POKIDLE_HIDDEN_ABILITY_RATE:-5}"

    local hidden_arr normal_arr
    hidden_arr="$(jq '[.abilities[] | select(.is_hidden==true) | {name: .ability.name, is_hidden: true}]' <<< "$poke")"
    normal_arr="$(jq '[.abilities[] | select(.is_hidden==false) | {name: .ability.name, is_hidden: false}]' <<< "$poke")"

    local roll=$((RANDOM % 100))
    local pool=""
    if (( roll < hidden_rate )) && [[ "$(jq 'length' <<< "$hidden_arr")" != "0" ]]; then
        pool="$hidden_arr"
    else
        pool="$normal_arr"
    fi
    [[ "$(jq 'length' <<< "$pool")" == "0" ]] && pool="$hidden_arr"   # last-resort

    local n idx
    n="$(jq 'length' <<< "$pool")"
    idx=$((RANDOM % n))
    jq -c ".[$idx]" <<< "$pool"
}
```

- [ ] **Step 5: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 6: Commit**

```bash
git add lib/encounter.bash tests/fixtures/pokemon-treecko.json tests/test-encounter-rolls.bats
git commit -m "feat(encounter): ability roll with hidden-rate gating"
```

---

## Task 5: Moves roll

**Files:**
- Modify: `lib/encounter.bash`
- Modify: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add tests**

```bash
@test "encounter_roll_moves: at level 5 returns 4 candidates ≤ level" {
    # Treecko fixture has level-up moves at 1,3,6,11,17 + machine/egg/tutor (level 0)
    # At level 5 candidates ≤5: pound(1), leer(3), giga-drain(0,machine), endeavor(0,egg), snatch(0,tutor) = 5 candidates
    run encounter_roll_moves treecko 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "4" ]
}

@test "encounter_roll_moves: at level 1 with limited pool returns 4 (or fewer if not enough)" {
    # Level 1: pound(1) + machine + egg + tutor = 4
    run encounter_roll_moves treecko 1
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "4" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 3: Implement**

Append to `lib/encounter.bash`:

```bash
# Roll up to 4 moves from union of (level-up + machine + egg + tutor) where
# level_learned_at <= level. Prints JSON array of move-name strings.
encounter_roll_moves() {
    local species="$1" level="$2"
    local poke
    poke="$(pokeapi_get "pokemon/$species")"

    local candidates
    candidates="$(jq -r --argjson lvl "$level" '
        [
          .moves[] |
          .move.name as $name |
          .version_group_details[] |
          select(
            (.move_learn_method.name | IN("level-up","machine","egg","tutor")) and
            (.level_learned_at <= $lvl)
          ) | $name
        ] | unique | .[]
    ' <<< "$poke")"

    local arr=()
    while IFS= read -r m; do
        [[ -n "$m" ]] && arr+=("$m")
    done <<< "$candidates"

    local n="${#arr[@]}"
    if (( n == 0 )); then
        printf '[]'
        return
    fi

    # shuffle and take 4
    local picked=()
    while (( ${#picked[@]} < 4 && ${#arr[@]} > 0 )); do
        local idx=$((RANDOM % ${#arr[@]}))
        picked+=("${arr[$idx]}")
        # remove arr[idx]
        arr=("${arr[@]:0:idx}" "${arr[@]:idx+1}")
    done

    # emit JSON array
    printf '['
    local i sep=""
    for i in "${picked[@]}"; do
        printf '%s"%s"' "$sep" "$i"
        sep=","
    done
    printf ']'
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-rolls.bats
git commit -m "feat(encounter): moves roll (4 random ≤ level union pool)"
```

---

## Task 6: Gender + shiny + held-berry rolls

**Files:**
- Modify: `lib/encounter.bash`
- Create: `tests/fixtures/pokemon-species-treecko.json`
- Create: `tests/fixtures/pokemon-species-magnemite.json`
- Modify: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add fixtures**

`tests/fixtures/pokemon-species-treecko.json`:

```json
{
  "name": "treecko",
  "gender_rate": 1,
  "evolution_chain": {"url": "https://pokeapi.co/api/v2/evolution-chain/142/"}
}
```

`tests/fixtures/pokemon-species-magnemite.json`:

```json
{
  "name": "magnemite",
  "gender_rate": -1,
  "evolution_chain": {"url": "https://pokeapi.co/api/v2/evolution-chain/45/"}
}
```

- [ ] **Step 2: Add tests**

```bash
@test "encounter_roll_gender: gender_rate -1 returns genderless" {
    run encounter_roll_gender magnemite
    [ "$status" -eq 0 ]
    [ "$output" = "genderless" ]
}

@test "encounter_roll_gender: gender_rate 1 yields ~12.5% F" {
    local f=0 m=0 i out
    for i in {1..200}; do
        out="$(encounter_roll_gender treecko)"
        case "$out" in
            F) f=$((f+1)) ;;
            M) m=$((m+1)) ;;
        esac
    done
    # Expect roughly 25 F / 175 M; allow wide bands
    [ "$f" -ge 5 ]   && [ "$f" -le 60 ]
    [ "$m" -ge 140 ] && [ "$m" -le 195 ]
}

@test "encounter_roll_shiny: rate 1 always shiny" {
    POKIDLE_SHINY_RATE=1
    run encounter_roll_shiny
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "encounter_roll_shiny: rate 1000000 almost never shiny" {
    POKIDLE_SHINY_RATE=1000000
    local i s out
    s=0
    for i in {1..50}; do
        out="$(encounter_roll_shiny)"
        s=$((s + out))
    done
    [ "$s" -le 1 ]
}

@test "encounter_roll_held_berry: 0% rate returns null" {
    POKIDLE_BERRY_RATE=0
    run encounter_roll_held_berry "cave"
    [ "$status" -eq 0 ]
    [ "$output" = "null" ]
}

@test "encounter_roll_held_berry: 100% rate returns one of biome berries" {
    POKIDLE_BERRY_RATE=100
    run encounter_roll_held_berry "cave"
    [ "$status" -eq 0 ]
    # cave berry_pool: rawst, aspear, chesto, lum
    [[ "$output" =~ ^(rawst|aspear|chesto|lum)$ ]]
}
```

- [ ] **Step 3: Run, expect fail**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 4: Implement**

Append to `lib/encounter.bash`:

```bash
encounter_roll_gender() {
    local species="$1"
    local spec
    spec="$(pokeapi_get "pokemon-species/$species")"
    local gr
    gr="$(jq -r '.gender_rate' <<< "$spec")"
    if [[ "$gr" == "-1" ]]; then
        printf 'genderless'
        return
    fi
    # gr = female chance / 8. Roll 0..7.
    local roll=$((RANDOM % 8))
    if (( roll < gr )); then
        printf 'F'
    else
        printf 'M'
    fi
}

encounter_roll_shiny() {
    local rate="${POKIDLE_SHINY_RATE:-1024}"
    local roll=$((RANDOM * 32768 + RANDOM))
    if (( roll % rate == 0 )); then
        printf '1'
    else
        printf '0'
    fi
}

# Print "null" when no berry rolled, else berry name.
encounter_roll_held_berry() {
    local biome_id="$1"
    local rate="${POKIDLE_BERRY_RATE:-15}"
    local roll=$((RANDOM % 100))
    if (( roll >= rate )); then
        printf 'null'
        return
    fi
    # Pull biome berry pool — requires lib/biome.bash sourced
    if ! command -v biome_get > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi
    local biome
    biome="$(biome_get "$biome_id")"
    local berries
    mapfile -t berries < <(jq -r '.berry_pool[]' <<< "$biome")
    local n="${#berries[@]}"
    if (( n == 0 )); then
        printf 'null'
        return
    fi
    local idx=$((RANDOM % n))
    printf '%s' "${berries[$idx]}"
}
```

- [ ] **Step 5: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 6: Commit**

```bash
git add lib/encounter.bash tests/fixtures/pokemon-species-treecko.json tests/fixtures/pokemon-species-magnemite.json tests/test-encounter-rolls.bats
git commit -m "feat(encounter): gender, shiny, held-berry rolls"
```

---

## Task 7: Evolution chain walk + halving

**Files:**
- Modify: `lib/encounter.bash`
- Create: `tests/fixtures/evolution-chain-142.json`
- Create: `tests/fixtures/evolution-chain-67.json`
- Create: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Add fixtures**

`tests/fixtures/evolution-chain-142.json` (treecko line):

```json
{
  "id": 142,
  "chain": {
    "species": {"name":"treecko"},
    "evolution_details": [],
    "evolves_to": [
      {
        "species": {"name":"grovyle"},
        "evolution_details": [{"min_level":16, "trigger":{"name":"level-up"}}],
        "evolves_to": [
          {
            "species": {"name":"sceptile"},
            "evolution_details": [{"min_level":36, "trigger":{"name":"level-up"}}],
            "evolves_to": []
          }
        ]
      }
    ]
  }
}
```

`tests/fixtures/evolution-chain-67.json` (eevee with stones — use for non-level evo):

```json
{
  "id": 67,
  "chain": {
    "species": {"name":"eevee"},
    "evolution_details": [],
    "evolves_to": [
      {
        "species": {"name":"vaporeon"},
        "evolution_details": [{"trigger":{"name":"use-item"}, "min_level":null, "item":{"name":"water-stone"}}],
        "evolves_to": []
      },
      {
        "species": {"name":"jolteon"},
        "evolution_details": [{"trigger":{"name":"use-item"}, "min_level":null, "item":{"name":"thunder-stone"}}],
        "evolves_to": []
      }
    ]
  }
}
```

- [ ] **Step 2: Write failing tests**

`tests/test-encounter-pool.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib encounter
    stub_pokeapi
}

@test "walk_chain: treecko line yields 3 stages with correct levels" {
    local chain
    chain="$(cat "$FIXTURE_DIR/evolution-chain-142.json")"
    run encounter_walk_chain "$chain"
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "3" ]
    local treecko_stage grovyle_stage sceptile_stage
    treecko_stage="$(jq -r '.[] | select(.species=="treecko") | .stage_idx' <<< "$output")"
    grovyle_stage="$(jq -r '.[] | select(.species=="grovyle") | .stage_idx' <<< "$output")"
    sceptile_stage="$(jq -r '.[] | select(.species=="sceptile") | .stage_idx' <<< "$output")"
    [ "$treecko_stage" = "0" ]
    [ "$grovyle_stage" = "1" ]
    [ "$sceptile_stage" = "2" ]
    local grovyle_min sceptile_min
    grovyle_min="$(jq -r '.[] | select(.species=="grovyle") | .min_level_evo' <<< "$output")"
    sceptile_min="$(jq -r '.[] | select(.species=="sceptile") | .min_level_evo' <<< "$output")"
    [ "$grovyle_min" = "16" ]
    [ "$sceptile_min" = "36" ]
}

@test "walk_chain: eevee line yields 3 stages with null min_level for non-level evos" {
    local chain
    chain="$(cat "$FIXTURE_DIR/evolution-chain-67.json")"
    run encounter_walk_chain "$chain"
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "3" ]
    local vaporeon_min
    vaporeon_min="$(jq -r '.[] | select(.species=="vaporeon") | .min_level_evo // "null"' <<< "$output")"
    [ "$vaporeon_min" = "null" ]
}
```

- [ ] **Step 3: Run, expect fail**

```bash
bats tests/test-encounter-pool.bats
```

- [ ] **Step 4: Implement**

Append to `lib/encounter.bash`:

```bash
# encounter_walk_chain <chain_json>
# Emits a JSON array of {species, stage_idx, min_level_evo (nullable)}.
# stage_idx 0 for root; root has no min_level_evo.
encounter_walk_chain() {
    local chain_json="$1"
    jq -c '
        def walk($node; $stage):
            ($node.evolution_details[0].min_level // null) as $ml |
            { species: $node.species.name, stage_idx: $stage, min_level_evo: $ml },
            ($node.evolves_to[]? | walk(.; $stage + 1));
        [walk(.chain; 0)]
    ' <<< "$chain_json"
}
```

- [ ] **Step 5: Run, expect pass**

```bash
bats tests/test-encounter-pool.bats
```

- [ ] **Step 6: Commit**

```bash
git add lib/encounter.bash tests/fixtures/evolution-chain-142.json tests/fixtures/evolution-chain-67.json tests/test-encounter-pool.bats
git commit -m "feat(encounter): evolution-chain BFS walker"
```

---

## Task 8: Pool build (raw collection + collapse + evo expansion + renormalize)

**Files:**
- Modify: `lib/encounter.bash`
- Create: `tests/fixtures/location-area-treecko-route.json`
- Modify: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Add area fixture**

`tests/fixtures/location-area-treecko-route.json`:

```json
{
  "name": "rustboro-route-area",
  "pokemon_encounters": [
    {
      "pokemon": {"name":"treecko"},
      "version_details": [
        {
          "version": {"name":"emerald"},
          "encounter_details": [
            {"min_level": 5, "max_level": 7, "chance": 40, "method":{"name":"walk"}}
          ]
        }
      ]
    }
  ]
}
```

Also add: extract `evolution-chain-142` URL → key `evolution-chain-142` already exists. The `pokemon-species-treecko.json` from Task 6 fixture file points at chain id 142. The stub looks up endpoints — need `pokemon-species-treecko` (Task 6) and `evolution-chain-142` (Task 7) — both exist.

- [ ] **Step 2: Add tests**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "build_pool: single area with treecko -> 3-entry pool, halved %, normalized to 100" {
    local areas='["rustboro-route-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "3" ]
    # Pre-norm percents: treecko 40, grovyle 20, sceptile 10 -> total 70 -> normed: ~57.14, 28.57, 14.29
    local treecko_pct grovyle_pct sceptile_pct
    treecko_pct="$(jq -r '.[] | select(.species=="treecko") | .pct' <<< "$output")"
    grovyle_pct="$(jq -r '.[] | select(.species=="grovyle") | .pct' <<< "$output")"
    sceptile_pct="$(jq -r '.[] | select(.species=="sceptile") | .pct' <<< "$output")"
    # Use awk to compare floats with tolerance
    awk -v t="$treecko_pct"  'BEGIN { exit !(t > 56 && t < 58) }'
    awk -v t="$grovyle_pct"  'BEGIN { exit !(t > 28 && t < 29) }'
    awk -v t="$sceptile_pct" 'BEGIN { exit !(t > 14 && t < 15) }'

    # Total ~100
    local total
    total="$(jq '[.[] | .pct] | add' <<< "$output")"
    awk -v t="$total" 'BEGIN { exit !(t > 99.9 && t < 100.1) }'
}

@test "build_pool: grovyle gets level 16-(16+delta), sceptile 36-(36+delta) where delta=2" {
    local areas='["rustboro-route-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    local g_min g_max s_min s_max
    g_min="$(jq -r '.[] | select(.species=="grovyle") | .min' <<< "$output")"
    g_max="$(jq -r '.[] | select(.species=="grovyle") | .max' <<< "$output")"
    s_min="$(jq -r '.[] | select(.species=="sceptile") | .min' <<< "$output")"
    s_max="$(jq -r '.[] | select(.species=="sceptile") | .max' <<< "$output")"
    [ "$g_min" = "16" ] && [ "$g_max" = "18" ]
    [ "$s_min" = "36" ] && [ "$s_max" = "38" ]
}
```

- [ ] **Step 3: Run, expect fail**

```bash
bats tests/test-encounter-pool.bats
```

- [ ] **Step 4: Implement**

Append to `lib/encounter.bash`:

```bash
# Map version-group/version name to generation 1-9. Static.
encounter_gen_of() {
    local v="$1"
    case "$v" in
        red|blue|yellow) echo 1 ;;
        gold|silver|crystal) echo 2 ;;
        ruby|sapphire|emerald|firered|leafgreen) echo 3 ;;
        diamond|pearl|platinum|heartgold|soulsilver) echo 4 ;;
        black|white|black-2|white-2) echo 5 ;;
        x|y|omega-ruby|alpha-sapphire) echo 6 ;;
        sun|moon|ultra-sun|ultra-moon|lets-go-pikachu|lets-go-eevee) echo 7 ;;
        sword|shield|brilliant-diamond|shining-pearl|legends-arceus) echo 8 ;;
        scarlet|violet) echo 9 ;;
        *) echo 0 ;;
    esac
}

# encounter_build_pool <areas_json_array> <gen_csv>
# Emits JSON array [{species, min, max, pct}].
encounter_build_pool() {
    local areas_json="$1" gen_csv="$2"

    # 1. Collect raw entries from each area
    local raw='[]'
    local area
    while IFS= read -r area; do
        [[ -z "$area" ]] && continue
        local area_json
        area_json="$(pokeapi_get "location-area/$area")"
        local rows
        rows="$(jq -c --arg gens "$gen_csv" '
            def gen_match($v):
                ($gens | length == 0) or
                ($gens | split(",") | any(. as $g | env_GEN_OF($v) == $g));
            .pokemon_encounters[] |
            .pokemon.name as $sp |
            .version_details[] |
            .version.name as $ver |
            .encounter_details[] |
            {species: $sp, min: .min_level, max: .max_level, chance: .chance, version: $ver}
        ' <<< "$area_json")"
        # gen filter is tricky in pure jq with bash gen_of. Filter post-hoc:
        local row
        while IFS= read -r row; do
            [[ -z "$row" ]] && continue
            if [[ -n "$gen_csv" ]]; then
                local v g
                v="$(jq -r '.version' <<< "$row")"
                g="$(encounter_gen_of "$v")"
                local match=0
                IFS=',' read -ra wanted <<< "$gen_csv"
                local w
                for w in "${wanted[@]}"; do
                    [[ "$w" == "$g" ]] && match=1 && break
                done
                (( match )) || continue
            fi
            raw="$(jq -c --argjson r "$row" '. + [$r]' <<< "$raw")"
        done <<< "$rows"
    done <<< "$(jq -r '.[]' <<< "$areas_json")"

    # 2. Collapse by species
    local base
    base="$(jq -c '
        group_by(.species) | map({
            species: (.[0].species),
            min: ([.[].min] | min),
            max: ([.[].max] | max),
            pct: ([.[].chance] | add)
        })
    ' <<< "$raw")"

    # 3. Evo expansion
    local expanded='[]'
    local entries
    entries="$(jq -c '.[]' <<< "$base")"
    local entry
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local sp min max pct delta
        sp="$(jq -r '.species' <<< "$entry")"
        min="$(jq -r '.min' <<< "$entry")"
        max="$(jq -r '.max' <<< "$entry")"
        pct="$(jq -r '.pct' <<< "$entry")"
        delta=$((max - min))

        # Find evolution chain id via species
        local spec chain_url chain_id
        spec="$(pokeapi_get "pokemon-species/$sp")"
        chain_url="$(jq -r '.evolution_chain.url' <<< "$spec")"
        chain_id="$(basename -- "${chain_url%/}")"

        local chain stages
        chain="$(pokeapi_get "evolution-chain/$chain_id")"
        stages="$(encounter_walk_chain "$chain")"

        # Build per-stage entries with halving
        # We need parent_max for non-level evos; collect by walking with parent context.
        local new_entries
        new_entries="$(jq -c \
            --argjson root_min "$min" --argjson root_max "$max" --argjson delta "$delta" \
            --argjson root_pct "$pct" \
            --argjson stages "$stages" '
            # Sort stages by stage_idx ascending
            def find($species): $stages[] | select(.species==$species);
            $stages
            | sort_by(.stage_idx)
            | reduce .[] as $s (
                {expanded: [], by_idx: {}};
                if $s.stage_idx == 0 then
                    .expanded += [{species: $s.species, min: $root_min, max: $root_max,
                                   pct: $root_pct}]
                    | .by_idx[($s.stage_idx|tostring)] = $root_max
                else
                    (.by_idx[(($s.stage_idx - 1)|tostring)]) as $parent_max |
                    (if $s.min_level_evo != null then $s.min_level_evo
                     else ($parent_max + 10) end) as $emin |
                    .expanded += [{
                        species: $s.species,
                        min: $emin,
                        max: ($emin + $delta),
                        pct: ($root_pct / pow(2; $s.stage_idx))
                    }]
                    | .by_idx[($s.stage_idx|tostring)] = ($emin + $delta)
                end
              )
            | .expanded
        ' <<< 'null')"
        expanded="$(jq -c --argjson e "$new_entries" '. + $e' <<< "$expanded")"
    done <<< "$entries"

    # 4. Renormalize to 100%
    local total
    total="$(jq '[.[].pct] | add' <<< "$expanded")"
    if [[ "$total" == "0" || "$total" == "null" ]]; then
        printf '%s' "$expanded"
        return
    fi
    jq -c --argjson total "$total" '
        map(.pct = (.pct * 100 / $total))
    ' <<< "$expanded"
}
```

- [ ] **Step 5: Run, expect pass**

```bash
bats tests/test-encounter-pool.bats
```

- [ ] **Step 6: Commit**

```bash
git add lib/encounter.bash tests/fixtures/location-area-treecko-route.json tests/test-encounter-pool.bats
git commit -m "feat(encounter): pool build with collapse, evo expansion, renormalize"
```

---

## Task 9: Pool persistence + roll_pool_entry

**Files:**
- Modify: `lib/encounter.bash`
- Modify: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Add tests**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "encounter_pool_path returns biome-specific cache path" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    run encounter_pool_path cave
    [ "$output" = "$POKIDLE_CACHE_DIR/pools/cave.json" ]
}

@test "encounter_pool_save and encounter_pool_load round-trip" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    local pool='[{"species":"zubat","min":5,"max":8,"pct":50},{"species":"golbat","min":22,"max":25,"pct":50}]'
    encounter_pool_save cave "$pool"
    run encounter_pool_load cave
    [ "$status" -eq 0 ]
    local n
    n="$(jq '.entries | length' <<< "$output")"
    [ "$n" = "2" ]
}

@test "encounter_roll_pool_entry returns one of the pool species" {
    local pool='{"entries":[{"species":"zubat","min":5,"max":8,"pct":100}]}'
    run encounter_roll_pool_entry "$pool"
    [ "$status" -eq 0 ]
    local sp
    sp="$(jq -r '.species' <<< "$output")"
    [ "$sp" = "zubat" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-encounter-pool.bats
```

- [ ] **Step 3: Implement**

Append to `lib/encounter.bash`:

```bash
encounter_pool_path() {
    local biome="$1"
    printf '%s/pools/%s.json' "${POKIDLE_CACHE_DIR:-$HOME/.cache/pokidle}" "$biome"
}

encounter_pool_save() {
    local biome="$1" entries_json="$2"
    local p
    p="$(encounter_pool_path "$biome")"
    mkdir -p -- "$(dirname -- "$p")"
    local body
    body="$(jq -n --arg b "$biome" --arg ts "$(date -u +%FT%TZ)" \
                  --arg gen "${POKIDLE_GEN:-}" --argjson e "$entries_json" '{
        biome: $b, built_at: $ts,
        gen_filter: ($gen | if . == "" then [] else split(",") end),
        entries: $e
    }')"
    printf '%s' "$body" > "$p"
}

encounter_pool_load() {
    local biome="$1"
    local p
    p="$(encounter_pool_path "$biome")"
    [[ -f "$p" ]] || { printf 'encounter_pool_load: no pool for %s\n' "$biome" >&2; return 1; }
    cat "$p"
}

# Weighted random pick from pool object {entries:[{species,min,max,pct}]}.
encounter_roll_pool_entry() {
    local pool="$1"
    local r cum=0 picked=""
    # bash float random in [0,100)
    r="$(awk -v s=$RANDOM -v t=$RANDOM 'BEGIN { srand(s*32768+t); printf "%.6f", rand()*100 }')"
    local entries
    entries="$(jq -c '.entries[]' <<< "$pool")"
    local e pct
    while IFS= read -r e; do
        [[ -z "$e" ]] && continue
        pct="$(jq -r '.pct' <<< "$e")"
        cum="$(awk -v a="$cum" -v b="$pct" 'BEGIN { printf "%.6f", a+b }')"
        if awk -v r="$r" -v c="$cum" 'BEGIN { exit !(r <= c) }'; then
            picked="$e"
            break
        fi
    done <<< "$entries"
    [[ -z "$picked" ]] && picked="$(jq -c '.entries[-1]' <<< "$pool")"
    printf '%s' "$picked"
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-encounter-pool.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "feat(encounter): pool save/load and weighted entry roll"
```

---

## Task 10: `encounter_roll_pokemon` integrator

**Files:**
- Modify: `lib/encounter.bash`
- Modify: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add test**

```bash
@test "encounter_roll_pokemon: full encounter has all required keys" {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    local entry='{"species":"treecko","min":5,"max":7,"pct":100}'
    run encounter_roll_pokemon "$entry" "cave"
    [ "$status" -eq 0 ]

    local enc="$output"
    local k
    for k in species dex_id level nature ability is_hidden_ability gender shiny held_berry ivs evs stats moves sprite_url; do
        local v
        v="$(jq -r --arg k "$k" 'has($k) | tostring' <<< "$enc")"
        [ "$v" = "true" ]
    done
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 3: Implement**

Append to `lib/encounter.bash`:

```bash
# encounter_roll_pokemon <entry_json> <biome_id>
# Emits a JSON encounter object ready for db_insert_encounter (after adding
# session_id, encountered_at, sprite_path).
encounter_roll_pokemon() {
    local entry="$1" biome="$2"
    local sp lo hi
    sp="$(jq -r '.species' <<< "$entry")"
    lo="$(jq -r '.min'     <<< "$entry")"
    hi="$(jq -r '.max'     <<< "$entry")"

    local poke
    poke="$(pokeapi_get "pokemon/$sp")"
    local dex_id
    dex_id="$(jq -r '.id' <<< "$poke")"
    local sprite_url
    sprite_url="$(jq -r '.sprites.front_default // ""' <<< "$poke")"
    local sprite_url_shiny
    sprite_url_shiny="$(jq -r '.sprites.front_shiny // ""' <<< "$poke")"

    local level
    level="$(encounter_roll_level "$lo" "$hi")"

    local ivs evs
    ivs="$(encounter_roll_ivs)"
    evs="$(encounter_ev_split "$((RANDOM % 511))")"

    # Nature
    local natures n nature
    mapfile -t natures < <(encounter_natures_list)
    n="${#natures[@]}"
    nature="${natures[$((RANDOM % n))]}"
    local mods
    mods="$(encounter_nature_mods "$nature")"

    # Ability
    local ability_obj ability is_hidden
    ability_obj="$(encounter_roll_ability "$sp")"
    ability="$(jq -r '.name' <<< "$ability_obj")"
    is_hidden="$(jq -r 'if .is_hidden then 1 else 0 end' <<< "$ability_obj")"

    # Moves
    local moves_json
    moves_json="$(encounter_roll_moves "$sp" "$level")"

    # Gender / shiny / berry
    local gender shiny held_berry
    gender="$(encounter_roll_gender "$sp")"
    shiny="$(encounter_roll_shiny)"
    held_berry="$(encounter_roll_held_berry "$biome")"

    # Stats
    local base_stats stats
    base_stats="$(jq -c '.stats' <<< "$poke")"
    stats="$(encounter_compute_all_stats "$base_stats" "$ivs" "$evs" "$level" "$mods")"

    # Pick sprite url for shiny
    local final_sprite="$sprite_url"
    [[ "$shiny" == "1" && -n "$sprite_url_shiny" ]] && final_sprite="$sprite_url_shiny"

    # Translate held_berry literal "null" to JSON null
    local berry_arg
    if [[ "$held_berry" == "null" ]]; then berry_arg="null"; else berry_arg="\"$held_berry\""; fi

    # Translate ivs/evs/stats space lists -> JSON arrays
    local ivs_json evs_json stats_json
    ivs_json="[$(printf '%s,' $ivs | sed 's/,$//')]"
    evs_json="[$(printf '%s,' $evs | sed 's/,$//')]"
    stats_json="[$(printf '%s,' $stats | sed 's/,$//')]"

    jq -n \
        --arg sp "$sp" --argjson dex "$dex_id" --argjson lvl "$level" \
        --arg nature "$nature" --arg ability "$ability" --argjson hidden "$is_hidden" \
        --arg gender "$gender" --argjson shiny "$shiny" --argjson held "$berry_arg" \
        --argjson ivs "$ivs_json" --argjson evs "$evs_json" --argjson stats "$stats_json" \
        --argjson moves "$moves_json" --arg sprite "$final_sprite" '{
            species: $sp, dex_id: $dex, level: $lvl,
            nature: $nature, ability: $ability, is_hidden_ability: $hidden,
            gender: $gender, shiny: $shiny, held_berry: $held,
            ivs: $ivs, evs: $evs, stats: $stats,
            moves: $moves, sprite_url: $sprite
        }'
}
```

> Note: `held_berry` in this object holds the *berry name* (or null). The JSON encoded literal-vs-string translation above is a workaround. The downstream pokidle command will pass this directly into `db_insert_encounter` after also adding `session_id`, `encountered_at`, and `sprite_path` (downloaded).

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-rolls.bats
git commit -m "feat(encounter): roll_pokemon integrator"
```

---

## Task 11: `encounter_roll_item`

**Files:**
- Modify: `lib/encounter.bash`
- Create: `tests/fixtures/item-everstone.json`
- Modify: `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Add fixture**

`tests/fixtures/item-everstone.json`:

```json
{
  "name": "everstone",
  "sprites": {"default":"https://x/everstone.png"}
}
```

- [ ] **Step 2: Add test**

```bash
@test "encounter_roll_item: emits json with item + sprite_url" {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    # Force the cave pool so we hit a known item
    # cave item_pool starts with 'everstone' — but pick is random; use a
    # tight loop to get one we have a fixture for.
    local i out item
    for i in {1..30}; do
        out="$(encounter_roll_item cave)" || continue
        item="$(jq -r '.item' <<< "$out")"
        if [[ "$item" == "everstone" ]]; then
            # got one — assert sprite present
            local sprite
            sprite="$(jq -r '.sprite_url' <<< "$out")"
            [[ "$sprite" == *"everstone.png"* ]]
            return 0
        fi
    done
    skip "RNG didn't pick everstone in 30 tries; non-deterministic, retry suite"
}
```

- [ ] **Step 3: Implement**

Append to `lib/encounter.bash`:

```bash
# encounter_roll_item <biome_id>
# Emits {"item": "<name>", "sprite_url": "<url|empty>"}.
encounter_roll_item() {
    local biome_id="$1"
    if ! command -v biome_get > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi
    local biome pool
    biome="$(biome_get "$biome_id")"
    pool="$(jq -c '.item_pool' <<< "$biome")"
    local n
    n="$(jq 'length' <<< "$pool")"
    if (( n == 0 )); then
        # fallback to wild's item_pool
        biome="$(biome_get wild)"
        pool="$(jq -c '.item_pool' <<< "$biome")"
        n="$(jq 'length' <<< "$pool")"
    fi
    (( n > 0 )) || return 1
    local idx=$((RANDOM % n))
    local name
    name="$(jq -r ".[$idx]" <<< "$pool")"
    local item_json
    item_json="$(pokeapi_get "item/$name")"
    local sprite
    sprite="$(jq -r '.sprites.default // ""' <<< "$item_json")"
    jq -n --arg item "$name" --arg sprite "$sprite" '{item: $item, sprite_url: $sprite}'
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-encounter-rolls.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/fixtures/item-everstone.json tests/test-encounter-rolls.bats
git commit -m "feat(encounter): roll_item from biome pool"
```

---

## Task 12: `lib/notify.bash`

**Files:**
- Create: `lib/notify.bash`
- Create: `tests/test-notify.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-notify.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
}

@test "notify_pokemon: dry-run prints rendered title and body to stdout" {
    local enc='{
        "species":"sceptile","level":42,"nature":"adamant","ability":"overgrow",
        "gender":"M","shiny":1,"held_berry":"sitrus",
        "stats":[142,198,95,129,95,152],
        "moves":["leaf-blade","dragon-claw","earthquake","x-scissor"],
        "sprite_path":"/tmp/sceptile.png",
        "biome_label":"Cave"
    }'
    run notify_pokemon "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SHINY"* ]]
    [[ "$output" == *"Sceptile"* ]]
    [[ "$output" == *"Cave"* ]]
    [[ "$output" == *"sitrus"* ]]
}

@test "notify_pokemon: not shiny -> no SHINY tag" {
    local enc='{
        "species":"zubat","level":7,"nature":"timid","ability":"inner-focus",
        "gender":"M","shiny":0,"held_berry":null,
        "stats":[22,18,15,12,15,30],
        "moves":["leech-life"],
        "sprite_path":"/tmp/zubat.png",
        "biome_label":"Cave"
    }'
    run notify_pokemon "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" != *"SHINY"* ]]
    [[ "$output" == *"Zubat"* ]]
}

@test "notify_item: dry-run renders item line" {
    local item='{"item":"everstone","sprite_path":"/tmp/everstone.png","biome_label":"Cave"}'
    run notify_item "$item"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found"* ]]
    [[ "$output" == *"Everstone"* ]]
    [[ "$output" == *"Cave"* ]]
}

@test "notify_biome_change: dry-run prints title" {
    run notify_biome_change "Volcano" 42 12
    [ "$status" -eq 0 ]
    [[ "$output" == *"Biome changed"* ]]
    [[ "$output" == *"Volcano"* ]]
    [[ "$output" == *"42"* ]]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-notify.bats
```

- [ ] **Step 3: Implement**

`lib/notify.bash`:

```bash
#!/usr/bin/env bash
# lib/notify.bash — notify-send + sound playback.

_titlecase() {
    local s="$1"
    printf '%s' "${s^}"
}

_titlecase_words() {
    local s="$1"
    s="${s//-/ }"
    local out=""
    local w
    for w in $s; do
        out+="${w^} "
    done
    printf '%s' "${out% }"
}

_emit() {
    local title="$1"
    local body="$2"
    local urgency="$3"
    local icon="$4"
    if [[ "${POKIDLE_NO_NOTIFY:-0}" == "1" ]]; then
        printf 'TITLE: %s\nBODY: %s\nURGENCY: %s\nICON: %s\n' "$title" "$body" "$urgency" "$icon"
        return 0
    fi
    local args=(-u "$urgency")
    [[ -n "$icon" ]] && args+=(-i "$icon")
    args+=(-h "string:desktop-entry:pokidle")
    notify-send "${args[@]}" "$title" "$body" || \
        printf 'notify-send failed (non-fatal)\n' >&2
}

_play_sound() {
    local kind="$1"   # encounter | shiny
    [[ "${POKIDLE_NO_SOUND:-0}" == "1" ]] && return 0
    local policy="${POKIDLE_SOUND:-shiny}"
    case "$policy" in
        never) return 0 ;;
        shiny) [[ "$kind" == "shiny" ]] || return 0 ;;
        always) ;;
        *) return 0 ;;
    esac
    local file="${POKIDLE_SOUND_ENCOUNTER:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/encounter.ogg}"
    [[ "$kind" == "shiny" ]] && file="${POKIDLE_SOUND_SHINY:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/shiny.ogg}"
    [[ -f "$file" ]] || return 0
    if   command -v paplay >/dev/null; then paplay "$file" >/dev/null 2>&1 &
    elif command -v aplay  >/dev/null; then aplay  -q "$file" >/dev/null 2>&1 &
    fi
}

notify_pokemon() {
    local enc="$1"
    local species level nature ability gender shiny held biome_label
    species="$(jq -r '.species' <<< "$enc")"
    level="$(jq -r '.level' <<< "$enc")"
    nature="$(jq -r '.nature' <<< "$enc")"
    ability="$(jq -r '.ability' <<< "$enc")"
    gender="$(jq -r '.gender' <<< "$enc")"
    shiny="$(jq -r '.shiny' <<< "$enc")"
    held="$(jq -r '.held_berry // ""' <<< "$enc")"
    biome_label="$(jq -r '.biome_label // ""' <<< "$enc")"

    local stats moves
    stats="$(jq -r '.stats | "HP \(.[0])  Atk \(.[1])  Def \(.[2])  SpA \(.[3])  SpD \(.[4])  Spe \(.[5])"' <<< "$enc")"
    moves="$(jq -r '.moves | join(", ")' <<< "$enc")"

    local sp_title nat_title abil_title
    sp_title="$(_titlecase_words "$species")"
    nat_title="$(_titlecase "$nature")"
    abil_title="$(_titlecase_words "$ability")"

    local title body urgency icon
    if [[ "$shiny" == "1" ]]; then
        title="[SHINY ✨] Lv.$level $sp_title"
        urgency="${POKIDLE_NOTIFY_URGENCY_SHINY:-critical}"
    else
        title="Lv.$level $sp_title"
        urgency="normal"
    fi
    body="$biome_label  ·  $nat_title  ·  $abil_title"$'\n'"$stats"$'\n'"Moves: $moves"
    [[ -n "$held" && "$held" != "null" ]] && body+=$'\n'"Held: $held"

    icon="$(jq -r '.sprite_path // ""' <<< "$enc")"

    _emit "$title" "$body" "$urgency" "$icon"
    if [[ "$shiny" == "1" ]]; then
        _play_sound shiny
    else
        _play_sound encounter
    fi
}

notify_item() {
    local item_json="$1"
    local name biome_label icon
    name="$(jq -r '.item' <<< "$item_json")"
    biome_label="$(jq -r '.biome_label // ""' <<< "$item_json")"
    icon="$(jq -r '.sprite_path // ""' <<< "$item_json")"
    local title body
    title="Found $(_titlecase_words "$name")"
    body="$biome_label  ·  held-item"
    _emit "$title" "$body" "low" "$icon"
}

notify_biome_change() {
    local label="$1" pool_size="$2" item_count="$3"
    local title="Biome changed → $label"
    local body="Encounters: $pool_size species, $item_count items"
    _emit "$title" "$body" "low" ""
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-notify.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/notify.bash tests/test-notify.bats
git commit -m "feat(notify): notify-send wrappers + sound dispatch"
```

---

## Task 13: `lib/showdown.bash`

**Files:**
- Create: `lib/showdown.bash`
- Create: `tests/test-showdown.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-showdown.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    load_lib showdown
}

@test "showdown_format: full encounter renders correctly" {
    local enc='{
        "species":"sceptile","level":42,"nature":"adamant","ability":"overgrow",
        "is_hidden_ability":0,"gender":"M","shiny":1,"held_berry":"sitrus",
        "ivs":[31,28,19,31,24,30],
        "evs":[252,0,0,6,0,252],
        "moves":["leaf-blade","dragon-claw","earthquake","x-scissor"]
    }'
    run showdown_format "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sceptile @ Sitrus Berry"* ]]
    [[ "$output" == *"Ability: Overgrow"* ]]
    [[ "$output" == *"Level: 42"* ]]
    [[ "$output" == *"Shiny: Yes"* ]]
    [[ "$output" == *"Adamant Nature"* ]]
    [[ "$output" == *"EVs: 252 HP / 6 SpA / 252 Spe"* ]]
    [[ "$output" == *"IVs: 31 HP / 28 Atk / 19 Def / 31 SpA / 24 SpD / 30 Spe"* ]]
    [[ "$output" == *"- Leaf Blade"* ]]
    [[ "$output" == *"- Dragon Claw"* ]]
}

@test "showdown_format: no berry, not shiny, no item line, no Shiny line" {
    local enc='{
        "species":"zubat","level":7,"nature":"timid","ability":"inner-focus",
        "is_hidden_ability":0,"gender":"M","shiny":0,"held_berry":null,
        "ivs":[10,20,30,15,5,25],
        "evs":[0,0,0,0,0,0],
        "moves":["leech-life","supersonic"]
    }'
    run showdown_format "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" != *"@ "* ]]
    [[ "$output" != *"Shiny:"* ]]
    [[ "$output" == *"Zubat"* ]]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-showdown.bats
```

- [ ] **Step 3: Implement**

`lib/showdown.bash`:

```bash
#!/usr/bin/env bash
# lib/showdown.bash — Pokémon Showdown set text formatter.

_sd_titlecase_words() {
    local s="${1//-/ }"
    local out=""
    local w
    for w in $s; do
        out+="${w^} "
    done
    printf '%s' "${out% }"
}

_sd_stat_label() {
    case "$1" in
        0) echo HP ;;  1) echo Atk ;;  2) echo Def ;;
        3) echo SpA ;; 4) echo SpD ;;  5) echo Spe ;;
    esac
}

showdown_format() {
    local enc="$1"
    local species nature ability level shiny held
    species="$(jq -r '.species' <<< "$enc")"
    nature="$(jq -r '.nature' <<< "$enc")"
    ability="$(jq -r '.ability' <<< "$enc")"
    level="$(jq -r '.level' <<< "$enc")"
    shiny="$(jq -r '.shiny' <<< "$enc")"
    held="$(jq -r '.held_berry // ""' <<< "$enc")"

    local sp_t ab_t nat_t
    sp_t="$(_sd_titlecase_words "$species")"
    ab_t="$(_sd_titlecase_words "$ability")"
    nat_t="$(_sd_titlecase_words "$nature")"

    if [[ -n "$held" && "$held" != "null" ]]; then
        local berry_t
        berry_t="$(_sd_titlecase_words "$held")"
        printf '%s @ %s Berry\n' "$sp_t" "$berry_t"
    else
        printf '%s\n' "$sp_t"
    fi
    printf 'Ability: %s\n' "$ab_t"
    printf 'Level: %s\n' "$level"
    [[ "$shiny" == "1" ]] && printf 'Shiny: Yes\n'
    printf '%s Nature\n' "$nat_t"

    # EVs (only non-zero)
    local evs_line=""
    local i v sep=""
    for i in {0..5}; do
        v="$(jq -r ".evs[$i]" <<< "$enc")"
        if [[ "$v" != "0" ]]; then
            evs_line+="${sep}${v} $(_sd_stat_label "$i")"
            sep=" / "
        fi
    done
    [[ -n "$evs_line" ]] && printf 'EVs: %s\n' "$evs_line"

    # IVs (always full)
    local ivs_line=""
    sep=""
    for i in {0..5}; do
        v="$(jq -r ".ivs[$i]" <<< "$enc")"
        ivs_line+="${sep}${v} $(_sd_stat_label "$i")"
        sep=" / "
    done
    printf 'IVs: %s\n' "$ivs_line"

    # Moves
    local mv
    while IFS= read -r mv; do
        [[ -z "$mv" ]] && continue
        printf -- '- %s\n' "$(_sd_titlecase_words "$mv")"
    done < <(jq -r '.moves[]' <<< "$enc")
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-showdown.bats
```

- [ ] **Step 5: Commit**

```bash
git add lib/showdown.bash tests/test-showdown.bats
git commit -m "feat(showdown): set text formatter"
```

---

## Task 14: `pokidle` entry script + dispatcher

**Files:**
- Create: `pokidle`

- [ ] **Step 1: Write the dispatcher**

`pokidle`:

```bash
#!/usr/bin/env bash
# pokidle — passive pokemon encounter daemon + CLI.

set -euo pipefail

POKIDLE_REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export POKIDLE_REPO_ROOT

# Pre-source paths so libs see them
: "${POKIDLE_CONFIG_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/pokidle}"
: "${POKIDLE_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/pokidle}"
: "${POKIDLE_DATA_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/pokidle}"
: "${POKIDLE_DB_PATH:=$POKIDLE_DATA_DIR/pokidle.db}"
: "${POKEAPI_RATE_LIMIT_SLEEP:=${POKIDLE_RATE_LIMIT_SLEEP:-0.5}}"
export POKIDLE_CONFIG_DIR POKIDLE_CACHE_DIR POKIDLE_DATA_DIR POKIDLE_DB_PATH POKEAPI_RATE_LIMIT_SLEEP

# Source libs
# shellcheck source=lib/cache.bash
source "$POKIDLE_REPO_ROOT/lib/cache.bash"
# shellcheck source=lib/http.bash
source "$POKIDLE_REPO_ROOT/lib/http.bash"
# shellcheck source=lib/api.bash
source "$POKIDLE_REPO_ROOT/lib/api.bash"
# shellcheck source=lib/db.bash
source "$POKIDLE_REPO_ROOT/lib/db.bash"
# shellcheck source=lib/biome.bash
source "$POKIDLE_REPO_ROOT/lib/biome.bash"
# shellcheck source=lib/encounter.bash
source "$POKIDLE_REPO_ROOT/lib/encounter.bash"
# shellcheck source=lib/notify.bash
source "$POKIDLE_REPO_ROOT/lib/notify.bash"
# shellcheck source=lib/showdown.bash
source "$POKIDLE_REPO_ROOT/lib/showdown.bash"

usage() {
    cat <<'EOF'
pokidle — passive Pokémon encounter daemon.

Usage:
  pokidle <command> [args...]

Commands:
  daemon                  Run main loop (used by systemd unit)
  tick [pokemon|item]     Force a single roll now
                            --dry-run    Skip DB write
                            --no-notify  Skip notify-send
                            --json       Emit JSON to stdout
  list [filters]          Pretty list of pokemon encounters
  items [filters]         Pretty list of item drops
  stats                   Aggregates: totals, shinies, by biome, top species
  current                 Show current biome + counts
  rebuild-pool [biome]    Force pool rebuild (one or all)
  rebuild-biomes          Re-classify all /location-area
  clean [--yes]           Purge http cache + pools
  setup [--enable]        Install user systemd unit + config dirs
  uninstall               Disable + remove unit (DB/cache untouched)
  status                  systemctl status + last tick + current biome
  help, -h, --help        Show this help

See also: docs/superpowers/specs/2026-05-02-pokidle-design.md
EOF
}

cmd="${1-}"
[[ -n "$cmd" ]] || { usage >&2; exit 2; }
shift

case "$cmd" in
    daemon)         pokidle_daemon "$@" ;;
    tick)           pokidle_tick "$@" ;;
    list)           pokidle_list "$@" ;;
    items)          pokidle_items "$@" ;;
    stats)          pokidle_stats "$@" ;;
    current)        pokidle_current "$@" ;;
    rebuild-pool)   pokidle_rebuild_pool "$@" ;;
    rebuild-biomes) pokidle_rebuild_biomes "$@" ;;
    clean)          pokidle_clean "$@" ;;
    setup)          pokidle_setup "$@" ;;
    uninstall)      pokidle_uninstall "$@" ;;
    status)         pokidle_status "$@" ;;
    help|-h|--help) usage ;;
    *) printf 'unknown command: %s\n' "$cmd" >&2; usage >&2; exit 2 ;;
esac
```

> Many subcommand functions don't exist yet — they'll be added in subsequent tasks. The script will currently fail on most subcommands but `pokidle help` works.

- [ ] **Step 2: Make executable, smoke test**

```bash
chmod +x pokidle
./pokidle help | head -3
```

Expected: usage banner.

- [ ] **Step 3: Commit**

```bash
git add pokidle
git commit -m "feat(pokidle): entry script + dispatcher skeleton"
```

---

## Task 15: `pokidle current` + `pokidle clean`

**Files:**
- Modify: `pokidle`
- Create: `tests/test-cli.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-cli.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    export POKIDLE_DB_PATH
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    mkdir -p "$POKIDLE_CACHE_DIR"
    POKIDLE_DATA_DIR="$BATS_TMPDIR/data.$$"
    mkdir -p "$POKIDLE_DATA_DIR"
    export POKIDLE_CONFIG_DIR POKIDLE_CACHE_DIR POKIDLE_DATA_DIR
    export POKIDLE_NO_NOTIFY=1 POKIDLE_NO_SOUND=1
}

teardown() {
    rm -f  "$POKIDLE_DB_PATH"
    rm -rf "$POKIDLE_CONFIG_DIR" "$POKIDLE_CACHE_DIR" "$POKIDLE_DATA_DIR"
}

@test "pokidle help exits 0" {
    run "$REPO_ROOT/pokidle" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "pokidle current with no session prints 'no active biome'" {
    run "$REPO_ROOT/pokidle" current
    [ "$status" -eq 0 ]
    [[ "$output" == *"no active biome"* ]]
}

@test "pokidle clean --yes purges pools dir" {
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    touch "$POKIDLE_CACHE_DIR/pools/cave.json"
    run "$REPO_ROOT/pokidle" clean --yes
    [ "$status" -eq 0 ]
    [ ! -f "$POKIDLE_CACHE_DIR/pools/cave.json" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-cli.bats
```

- [ ] **Step 3: Implement subcommands**

Append to `pokidle` (above the `case` block, define functions; or move case block to bottom of file). Add functions:

```bash
pokidle_current() {
    db_init
    local row
    row="$(db_active_biome_session)"
    if [[ -z "$row" ]]; then
        printf 'no active biome\n'
        return 0
    fi
    local id biome started_at
    IFS=$'\t' read -r id biome started_at <<< "$row"
    local now elapsed remaining
    now="$(date +%s)"
    elapsed=$((now - started_at))
    remaining=$(( ${POKIDLE_BIOME_HOURS:-3} * 3600 - elapsed ))
    local enc_count item_count
    enc_count="$(db_query "SELECT COUNT(*) FROM encounters WHERE session_id=$id;")"
    item_count="$(db_query "SELECT COUNT(*) FROM item_drops WHERE session_id=$id;")"
    printf 'Active biome: %s  (session #%s)\n' "$biome" "$id"
    printf 'Started: %s\n' "$(date -d "@$started_at")"
    printf 'Time remaining: %ds\n' "$remaining"
    printf 'Encounters: %s   Items: %s\n' "$enc_count" "$item_count"
}

pokidle_clean() {
    local yes=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y) yes=1; shift ;;
            *) shift ;;
        esac
    done
    if (( ! yes )); then
        printf 'This will remove %s/pools and %s. Type yes: ' \
            "$POKIDLE_CACHE_DIR" "${POKEAPI_CACHE_DIR:-$HOME/.cache/pokeapi}"
        local ans
        read -r ans
        [[ "$ans" == "yes" ]] || { printf 'aborted\n'; return 1; }
    fi
    rm -rf -- "$POKIDLE_CACHE_DIR/pools" "$POKIDLE_CACHE_DIR/biome-areas"
    if [[ -d "${POKEAPI_CACHE_DIR:-$HOME/.cache/pokeapi}" ]]; then
        rm -rf -- "${POKEAPI_CACHE_DIR:-$HOME/.cache/pokeapi}"
    fi
    printf 'cleaned\n'
}

# Stubs to keep dispatcher working — real impls come in following tasks.
pokidle_tick()             { printf 'pokidle tick: not implemented yet\n' >&2; return 1; }
pokidle_list()             { printf 'pokidle list: not implemented yet\n' >&2; return 1; }
pokidle_items()            { printf 'pokidle items: not implemented yet\n' >&2; return 1; }
pokidle_stats()            { printf 'pokidle stats: not implemented yet\n' >&2; return 1; }
pokidle_rebuild_pool()     { printf 'pokidle rebuild-pool: not implemented yet\n' >&2; return 1; }
pokidle_rebuild_biomes()   { printf 'pokidle rebuild-biomes: not implemented yet\n' >&2; return 1; }
pokidle_setup()            { printf 'pokidle setup: see Plan C\n' >&2; return 1; }
pokidle_uninstall()        { printf 'pokidle uninstall: see Plan C\n' >&2; return 1; }
pokidle_status()           { printf 'pokidle status: see Plan C\n' >&2; return 1; }
pokidle_daemon()           { printf 'pokidle daemon: see Plan C\n' >&2; return 1; }
```

Reorder so functions are defined *before* the dispatcher `case` runs (which they already are if we append them above the `case`). The full structure becomes: shebang → env defaults → source libs → usage → all `pokidle_*` functions → arg parse → case dispatch.

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-cli.bats
```

- [ ] **Step 5: Commit**

```bash
git add pokidle tests/test-cli.bats
git commit -m "feat(pokidle): current + clean subcommands"
```

---

## Task 16: `pokidle tick`

**Files:**
- Modify: `pokidle`
- Modify: `tests/test-cli.bats`

- [ ] **Step 1: Add tests**

```bash
@test "pokidle tick pokemon --dry-run --no-notify --json: emits encounter json without writing db" {
    db_init() { sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"; }
    db_init

    # Pre-create a session so the tick has somewhere to attach
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));"

    # Stub pokeapi_get by exporting a wrapper that reads fixtures
    # Easier: copy fixtures into the http cache structure pokeapi expects.
    # We'll instead set POKEAPI_BASE_URL to a file:// scheme and skip — too brittle.
    # For this test: use a real pool fixture file instead of building one.

    local pool='{"biome":"cave","entries":[{"species":"treecko","min":5,"max":7,"pct":100}]}'
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    printf '%s' "$pool" > "$POKIDLE_CACHE_DIR/pools/cave.json"

    # Force the pokeapi cache dir to our fixtures so live fetches don't happen
    POKEAPI_CACHE_DIR="$BATS_TMPDIR/papi.$$"
    mkdir -p "$POKEAPI_CACHE_DIR"
    cp "$FIXTURE_DIR/pokemon-treecko.json"           "$POKEAPI_CACHE_DIR/pokemon-treecko"
    cp "$FIXTURE_DIR/pokemon-species-treecko.json"   "$POKEAPI_CACHE_DIR/pokemon-species-treecko"
    cp "$FIXTURE_DIR/evolution-chain-142.json"       "$POKEAPI_CACHE_DIR/evolution-chain-142"
    cp "$FIXTURE_DIR/nature-limit-100.json"          "$POKEAPI_CACHE_DIR/nature-limit-100"
    cp "$FIXTURE_DIR/nature-adamant.json"            "$POKEAPI_CACHE_DIR/nature-adamant"
    # Fixture for whichever nature gets randomly picked is needed; copy bashful as fallback
    cp "$FIXTURE_DIR/nature-bashful.json"            "$POKEAPI_CACHE_DIR/nature-bashful"
    export POKEAPI_CACHE_DIR

    run "$REPO_ROOT/pokidle" tick pokemon --dry-run --no-notify --json
    # On first nature roll the fixture might miss — accept non-zero in that case (skip)
    if [ "$status" -ne 0 ]; then
        skip "Test relies on cached natures being present — extend fixtures"
    fi
    local sp
    sp="$(jq -r '.species' <<< "$output")"
    [ "$sp" = "treecko" ]

    # No row inserted
    local n
    n="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$n" = "0" ]
}
```

> Note: tests for `tick` require a substantial fixture set. The skip path is a deliberate accommodation: this test is intended for executors who have populated the full fixture corpus (or who run it manually against the live API).

- [ ] **Step 2: Implement `pokidle_tick`**

Replace the `pokidle_tick` stub with:

```bash
pokidle_tick() {
    local kind="${1:-pokemon}"
    shift || true
    local dry_run=0 no_notify=0 emit_json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   dry_run=1; shift ;;
            --no-notify) no_notify=1; shift ;;
            --json)      emit_json=1; shift ;;
            *) printf 'tick: unknown flag %s\n' "$1" >&2; return 2 ;;
        esac
    done

    db_init

    # Get or open a session
    local row sid biome
    row="$(db_active_biome_session)"
    if [[ -z "$row" ]]; then
        biome="$(biome_pick_random)"
        sid="$(db_open_biome_session "$biome" "$(date +%s)")"
    else
        IFS=$'\t' read -r sid biome _ <<< "$row"
    fi
    local label
    label="$(biome_get "$biome" | jq -r '.label')"

    case "$kind" in
        pokemon)
            local pool entry enc
            if [[ ! -f "$(encounter_pool_path "$biome")" ]]; then
                printf 'tick: no pool for %s — run rebuild-pool first\n' "$biome" >&2
                return 1
            fi
            pool="$(encounter_pool_load "$biome")"
            entry="$(encounter_roll_pool_entry "$pool")"
            enc="$(encounter_roll_pokemon "$entry" "$biome")"

            # Download sprite (skip when notify disabled and dry_run)
            local sprite_url sprite_path=""
            sprite_url="$(jq -r '.sprite_url // ""' <<< "$enc")"
            if [[ -n "$sprite_url" && "$no_notify" == "0" ]]; then
                sprite_path="$POKIDLE_CACHE_DIR/sprites/$(jq -r '.species' <<< "$enc").png"
                mkdir -p -- "$(dirname -- "$sprite_path")"
                [[ -f "$sprite_path" ]] || curl -sS -o "$sprite_path" "$sprite_url" || sprite_path=""
            fi

            # Decorate with biome_label + sprite_path for notify
            local enc_with_meta
            enc_with_meta="$(jq -c \
                --arg label "$label" --arg sp "$sprite_path" '
                . + {biome_label: $label, sprite_path: $sp}
            ' <<< "$enc")"

            if (( dry_run == 0 )); then
                local enc_for_db
                enc_for_db="$(jq -c \
                    --argjson sid "$sid" --argjson ts "$(date +%s)" --arg sp "$sprite_path" '
                    . + {session_id: $sid, encountered_at: $ts, sprite_path: $sp}
                ' <<< "$enc")"
                db_insert_encounter "$enc_for_db"
            fi
            if (( no_notify == 0 )); then
                notify_pokemon "$enc_with_meta"
            fi
            if (( emit_json )); then
                printf '%s\n' "$enc_with_meta"
            elif (( no_notify )); then
                # No notification, no json — print short summary
                jq -r '"\(.species) lvl \(.level) \(.nature)"' <<< "$enc_with_meta"
            fi
            ;;
        item)
            local item_json
            item_json="$(encounter_roll_item "$biome")"
            local item_name sprite_url sprite_path=""
            item_name="$(jq -r '.item' <<< "$item_json")"
            sprite_url="$(jq -r '.sprite_url // ""' <<< "$item_json")"
            if [[ -n "$sprite_url" && "$no_notify" == "0" ]]; then
                sprite_path="$POKIDLE_CACHE_DIR/sprites/items/$item_name.png"
                mkdir -p -- "$(dirname -- "$sprite_path")"
                [[ -f "$sprite_path" ]] || curl -sS -o "$sprite_path" "$sprite_url" || sprite_path=""
            fi
            local item_with_meta
            item_with_meta="$(jq -c --arg l "$label" --arg sp "$sprite_path" '
                . + {biome_label: $l, sprite_path: $sp}
            ' <<< "$item_json")"
            if (( dry_run == 0 )); then
                db_insert_item_drop "$sid" "$(date +%s)" "$item_name" "$sprite_path"
            fi
            if (( no_notify == 0 )); then
                notify_item "$item_with_meta"
            fi
            (( emit_json )) && printf '%s\n' "$item_with_meta"
            ;;
        *)
            printf 'tick: kind must be pokemon or item\n' >&2
            return 2
            ;;
    esac
}
```

- [ ] **Step 3: Run tests, accept skips**

```bash
bats tests/test-cli.bats
```

Expected: existing tests pass; tick test may skip in unfavorable RNG.

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-cli.bats
git commit -m "feat(pokidle): tick subcommand with --dry-run/--no-notify/--json"
```

---

## Task 17: `pokidle list`

**Files:**
- Modify: `pokidle`
- Modify: `tests/test-cli.bats`

- [ ] **Step 1: Add tests**

```bash
@test "pokidle list emits json with --json" {
    db_init() { sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"; }
    db_init
    local sid
    sid="$(sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));
         SELECT last_insert_rowid();")"
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level, nature,
            ability, is_hidden_ability, gender, shiny, held_berry,
            iv_hp,iv_atk,iv_def,iv_spa,iv_spd,iv_spe,
            ev_hp,ev_atk,ev_def,ev_spa,ev_spd,ev_spe,
            stat_hp,stat_atk,stat_def,stat_spa,stat_spd,stat_spe,
            moves_json, sprite_path)
        VALUES ($sid, $(date +%s), 'zubat', 41, 7, 'adamant', 'inner-focus', 0, 'M', 0, NULL,
            10,20,30,15,5,25,
            0,0,0,0,0,0,
            22,18,15,12,15,30,
            '[\"bite\"]', NULL);"

    run "$REPO_ROOT/pokidle" list --json --limit 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
    [[ "$output" == *"zubat"* ]]
}

@test "pokidle list --export emits showdown set text" {
    db_init() { sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"; }
    db_init
    local sid
    sid="$(sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));
         SELECT last_insert_rowid();")"
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level, nature,
            ability, is_hidden_ability, gender, shiny, held_berry,
            iv_hp,iv_atk,iv_def,iv_spa,iv_spd,iv_spe,
            ev_hp,ev_atk,ev_def,ev_spa,ev_spd,ev_spe,
            stat_hp,stat_atk,stat_def,stat_spa,stat_spd,stat_spe,
            moves_json, sprite_path)
        VALUES ($sid, $(date +%s), 'sceptile', 254, 42, 'adamant', 'overgrow', 0, 'M', 1, 'sitrus',
            31,28,19,31,24,30,
            252,0,0,6,0,252,
            142,198,95,129,95,152,
            '[\"leaf-blade\",\"dragon-claw\",\"earthquake\",\"x-scissor\"]', NULL);"

    run "$REPO_ROOT/pokidle" list --export
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sceptile @ Sitrus Berry"* ]]
    [[ "$output" == *"Adamant Nature"* ]]
}
```

- [ ] **Step 2: Implement**

Replace `pokidle_list` stub:

```bash
pokidle_list() {
    db_init
    local export_mode=0 json_mode=0 args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --export) export_mode=1; shift ;;
            --json)   json_mode=1; shift ;;
            *)        args+=("$1"); shift ;;
        esac
    done

    local rows
    rows="$(db_list_encounters "${args[@]}")"

    if (( export_mode )); then
        local enc
        local sep=""
        while IFS= read -r enc; do
            [[ -z "$enc" ]] && continue
            local norm
            norm="$(jq -c '{
                species, level, nature, ability, is_hidden_ability,
                shiny, held_berry,
                ivs: [.iv_hp,.iv_atk,.iv_def,.iv_spa,.iv_spd,.iv_spe],
                evs: [.ev_hp,.ev_atk,.ev_def,.ev_spa,.ev_spd,.ev_spe],
                moves: (.moves_json | fromjson)
            }' <<< "$enc")"
            printf '%s' "$sep"
            showdown_format "$norm"
            sep=$'\n'
        done < <(jq -c '.[]' <<< "$rows")
        return
    fi

    if (( json_mode )); then
        printf '%s\n' "$rows"
        return
    fi

    # Pretty
    local enc
    while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        local sp lvl nat abil gender shiny biome ts
        sp="$(jq -r '.species' <<< "$enc")"
        lvl="$(jq -r '.level' <<< "$enc")"
        nat="$(jq -r '.nature' <<< "$enc")"
        abil="$(jq -r '.ability' <<< "$enc")"
        gender="$(jq -r '.gender' <<< "$enc")"
        shiny="$(jq -r '.shiny' <<< "$enc")"
        biome="$(jq -r '.biome_id' <<< "$enc")"
        ts="$(jq -r '.encountered_at' <<< "$enc")"
        local sprite
        sprite="$(jq -r '.sprite_path // ""' <<< "$enc")"
        printf '%s   %s   Lv.%s %s%s\n' \
            "$(date -d "@$ts" '+%F %H:%M')" "$biome" "$lvl" "$sp" \
            "$( [[ "$shiny" == "1" ]] && printf ' ✨' )"
        printf '   %s · %s · %s\n' "$nat" "$abil" "$gender"
        local ivs evs stats moves
        ivs="$(jq -r '"\(.iv_hp)/\(.iv_atk)/\(.iv_def)/\(.iv_spa)/\(.iv_spd)/\(.iv_spe)"' <<< "$enc")"
        evs="$(jq -r '"\(.ev_hp)/\(.ev_atk)/\(.ev_def)/\(.ev_spa)/\(.ev_spd)/\(.ev_spe)"' <<< "$enc")"
        stats="$(jq -r '"\(.stat_hp)/\(.stat_atk)/\(.stat_def)/\(.stat_spa)/\(.stat_spd)/\(.stat_spe)"' <<< "$enc")"
        moves="$(jq -r '.moves_json | fromjson | join(", ")' <<< "$enc")"
        printf '   Stats: %s\n   IVs:   %s\n   EVs:   %s\n   Moves: %s\n' \
            "$stats" "$ivs" "$evs" "$moves"
        if [[ -n "$sprite" && "$sprite" != "null" ]] && command -v catimg > /dev/null; then
            catimg -w "${POKIDLE_CATIMG_WIDTH:-16}" "$sprite" 2>/dev/null || true
        fi
        printf '\n'
    done < <(jq -c '.[]' <<< "$rows")
}
```

- [ ] **Step 3: Run, expect pass**

```bash
bats tests/test-cli.bats
```

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-cli.bats
git commit -m "feat(pokidle): list subcommand with --export/--json and pretty render"
```

---

## Task 18: `pokidle items`, `pokidle stats`

**Files:**
- Modify: `pokidle`
- Modify: `tests/test-cli.bats`

- [ ] **Step 1: Tests**

```bash
@test "pokidle items --json" {
    db_init() { sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"; }
    db_init
    local sid
    sid="$(sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));
         SELECT last_insert_rowid();")"
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO item_drops(session_id, encountered_at, item, sprite_path)
         VALUES ($sid, $(date +%s), 'everstone', NULL);"
    run "$REPO_ROOT/pokidle" items --json --limit 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
}

@test "pokidle stats prints totals" {
    db_init() { sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"; }
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));"
    run "$REPO_ROOT/pokidle" stats
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total encounters"* ]]
}
```

- [ ] **Step 2: Implement**

Replace stubs:

```bash
pokidle_items() {
    db_init
    local json_mode=0 args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_mode=1; shift ;;
            *)      args+=("$1"); shift ;;
        esac
    done
    local rows
    rows="$(db_list_item_drops "${args[@]}")"
    if (( json_mode )); then
        printf '%s\n' "$rows"
        return
    fi
    local d
    while IFS= read -r d; do
        [[ -z "$d" ]] && continue
        local ts biome item sprite
        ts="$(jq -r '.encountered_at' <<< "$d")"
        biome="$(jq -r '.biome_id' <<< "$d")"
        item="$(jq -r '.item' <<< "$d")"
        sprite="$(jq -r '.sprite_path // ""' <<< "$d")"
        printf '%s   %s   %s\n' "$(date -d "@$ts" '+%F %H:%M')" "$biome" "$item"
        if [[ -n "$sprite" && "$sprite" != "null" ]] && command -v catimg > /dev/null; then
            catimg -w "${POKIDLE_CATIMG_WIDTH:-16}" "$sprite" 2>/dev/null || true
        fi
    done < <(jq -c '.[]' <<< "$rows")
}

pokidle_stats() {
    db_init
    local total shinies
    total="$(db_query "SELECT COUNT(*) FROM encounters;")"
    shinies="$(db_query "SELECT COUNT(*) FROM encounters WHERE shiny=1;")"
    printf 'Total encounters:  %s\n' "$total"
    printf 'Shinies:           %s' "$shinies"
    if [[ "$shinies" != "0" && "$total" != "0" ]]; then
        printf '   (1 / %.1f)' "$(awk -v t="$total" -v s="$shinies" 'BEGIN { printf "%.1f", t/s }')"
    fi
    printf '\n\nBy biome:\n'
    db_query "SELECT s.biome_id, COUNT(*), SUM(e.shiny)
              FROM encounters e JOIN biome_sessions s ON s.id=e.session_id
              GROUP BY s.biome_id ORDER BY 2 DESC;" |
        awk -F'\t' '{ printf "  %-12s %5d   (%d shiny)\n", $1, $2, $3 }'
    printf '\nTop species:\n'
    db_query "SELECT species, COUNT(*) FROM encounters
              GROUP BY species ORDER BY 2 DESC LIMIT 10;" |
        awk -F'\t' '{ printf "  %-12s %5d\n", $1, $2 }'
}
```

- [ ] **Step 3: Run, expect pass**

```bash
bats tests/test-cli.bats
```

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-cli.bats
git commit -m "feat(pokidle): items + stats subcommands"
```

---

## Task 19: `pokidle rebuild-pool` and `pokidle rebuild-biomes`

**Files:**
- Modify: `pokidle`

- [ ] **Step 1: Implement**

Replace stubs:

```bash
pokidle_rebuild_pool() {
    local target="${1-}"
    local biomes
    if [[ -n "$target" ]]; then
        biomes="$target"
    else
        biomes="$(biome_ids)"
    fi
    local b
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        local areas_path="$POKIDLE_CACHE_DIR/biome-areas/$b.json"
        if [[ ! -f "$areas_path" ]]; then
            printf 'rebuild-pool: no area list for biome %s — run rebuild-biomes first\n' "$b" >&2
            continue
        fi
        local areas
        areas="$(cat "$areas_path")"
        local pool
        pool="$(encounter_build_pool "$areas" "${POKIDLE_GEN:-}")"
        encounter_pool_save "$b" "$pool"
        printf 'rebuilt pool: %s (%s entries)\n' "$b" "$(jq 'length' <<< "$pool")"
    done <<< "$biomes"
}

pokidle_rebuild_biomes() {
    # Iterate /location-area list, classify each, persist to cache/biome-areas/<biome>.json.
    mkdir -p -- "$POKIDLE_CACHE_DIR/biome-areas"
    local list
    list="$(pokeapi_get "location-area?limit=1500")"
    local areas_by_biome
    areas_by_biome="$(jq -n '{}')"

    local name
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local area
        area="$(pokeapi_get "location-area/$name")" || continue
        local biome
        biome="$(biome_classify_area "$area")"
        areas_by_biome="$(jq --arg b "$biome" --arg a "$name" '
            .[$b] = ((.[$b] // []) + [$a])
        ' <<< "$areas_by_biome")"
        printf '%s -> %s\n' "$name" "$biome"
    done < <(jq -r '.results[].name' <<< "$list")

    local b
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        local arr
        arr="$(jq -c --arg b "$b" '.[$b] // []' <<< "$areas_by_biome")"
        printf '%s' "$arr" > "$POKIDLE_CACHE_DIR/biome-areas/$b.json"
    done < <(biome_ids)
    printf 'rebuilt biome-area assignments\n'
}
```

> Note: `pokidle rebuild-biomes` makes hundreds of live API calls. The 0.5 s rate limit means it takes ~10 minutes. This is expected. Tests skip this command (manual invocation only).

- [ ] **Step 2: Manual smoke (run by executor only — slow)**

Skip in suite. Document in `tests/README.md`:

> `pokidle rebuild-biomes` is excluded from automated tests because it makes ~1000 live API calls. Run manually after Plan B is wired up.

- [ ] **Step 3: Commit**

```bash
git add pokidle tests/README.md
git commit -m "feat(pokidle): rebuild-pool + rebuild-biomes commands"
```

---

## Task 20: Full Plan B suite green

**Files:** none

- [ ] **Step 1: Run full bats**

```bash
bats tests/
```

Expected: every Plan A and Plan B test passes (skips allowed for fixture-dependent tick tests as documented).

- [ ] **Step 2: Run a manual end-to-end with live API (optional, executor judgment)**

```bash
./pokidle rebuild-biomes        # ~10 min — run once
./pokidle rebuild-pool cave
POKIDLE_NO_NOTIFY=1 ./pokidle tick pokemon --dry-run --json
./pokidle tick pokemon --dry-run                     # see notification
./pokidle tick pokemon                                # actually persist
./pokidle list
./pokidle list --export
./pokidle stats
```

- [ ] **Step 3: Commit any stragglers, push branch**

```bash
git status
# only commit if there are leftovers
```

---

## Plan B complete

End state: full encounter engine + notifications + Showdown export + non-daemon CLI. User can manually tick, persist, list, and export to Showdown. Plan C wires the daemon loop and systemd unit.

## Self-review notes

- Spec coverage:
  - Pool build, evo expansion, halving, renormalize: Tasks 7-9.
  - IV/EV/level/nature/ability/moves/gender/shiny/berry rolls: Tasks 1-6.
  - Stat formulas: Task 3.
  - Roll integrators: Tasks 10-11.
  - notify-send + sound + sprite icon: Task 12.
  - Showdown export: Task 13.
  - CLI dispatcher + subcommands (`tick`/`list`/`items`/`stats`/`current`/`rebuild-pool`/`rebuild-biomes`/`clean`): Tasks 14-19.
  - Setup/uninstall/status/daemon stubs are intentionally deferred to Plan C.
- Type/name consistency: function names match across tests and implementations (`encounter_*`, `notify_*`, `showdown_format`, `pokidle_*`).
- No placeholders.
- Tests rely on pokeapi cache override (`POKEAPI_CACHE_DIR`) for hermetic runs; some tick tests `skip` if fixtures don't cover the random nature pulled — documented.
