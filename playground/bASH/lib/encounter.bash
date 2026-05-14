#!/usr/bin/env bash
# lib/encounter.bash — pool build, evo expansion, rolls, stat formulas.
# Depends on pokeapi_get from lib/api.bash.

# All 6 stats in canonical order.
ENCOUNTER_STATS=(hp attack defense special-attack special-defense speed)

# Rarity tier definitions. ENCOUNTER_TIER_PCT_MIN[i] is the inclusive lower
# bound of tier ENCOUNTER_TIERS[i]; tiers are listed common-first.
ENCOUNTER_TIERS=(common uncommon rare very_rare)
ENCOUNTER_TIER_PCT_MIN=(25 10 3 0)
ENCOUNTER_TIER_ROLL_WEIGHT=(60 25 12 3)

# Held items by PokeAPI type. Each type maps to a space-separated string of item names.
declare -gA ENCOUNTER_HELD_ITEMS_BY_TYPE=(
    [normal]="silk-scarf chilan-berry"
    [fire]="charcoal flame-plate heat-rock occa-berry"
    [water]="mystic-water sea-incense wave-incense splash-plate wacan-berry"
    [electric]="magnet zap-plate cell-battery wacan-berry"
    [grass]="miracle-seed meadow-plate rose-incense rindo-berry"
    [ice]="never-melt-ice icicle-plate icy-rock yache-berry"
    [fighting]="black-belt fist-plate muscle-band chople-berry"
    [poison]="poison-barb toxic-plate black-sludge kebia-berry"
    [ground]="soft-sand earth-plate shuca-berry"
    [flying]="sharp-beak sky-plate pretty-feather coba-berry"
    [psychic]="twisted-spoon mind-plate odd-incense payapa-berry"
    [bug]="silver-powder insect-plate shed-shell tanga-berry"
    [rock]="hard-stone stone-plate rock-incense charti-berry"
    [ghost]="spell-tag spooky-plate reaper-cloth kasib-berry"
    [dragon]="dragon-fang draco-plate dragon-scale haban-berry"
    [dark]="black-glasses dread-plate scope-lens colbur-berry"
    [steel]="metal-coat iron-plate metal-powder"
    [fairy]="pixie-plate roseli-berry"
)

# Generic held items available for any biome type.
declare -ga ENCOUNTER_HELD_ITEMS_GENERIC=(
    "leftovers" "shell-bell" "lucky-egg" "amulet-coin"
    "smoke-ball" "soothe-bell" "exp-share" "everstone"
)

encounter_tier_for_pct() {
    local pct="$1" i
    for i in 0 1 2 3; do
        if (( pct >= ENCOUNTER_TIER_PCT_MIN[i] )); then
            printf '%s' "${ENCOUNTER_TIERS[$i]}"
            return
        fi
    done
    printf 'very_rare'
}

# capture_rate: PokeAPI value 0..255. Higher = easier to catch = more common.
# Thresholds: 150/75/25 bucket into common/uncommon/rare/very_rare.
encounter_tier_for_capture_rate() {
    local cr="$1"
    if   (( cr >= 150 )); then printf 'common'
    elif (( cr >= 75  )); then printf 'uncommon'
    elif (( cr >= 25  )); then printf 'rare'
    else                       printf 'very_rare'
    fi
}

# Shift a tier name N steps toward "very_rare", clamped.
encounter_tier_shift() {
    local tier="$1" steps="$2" i base target
    base=-1
    for i in 0 1 2 3; do
        if [[ "${ENCOUNTER_TIERS[$i]}" == "$tier" ]]; then
            base=$i
            break
        fi
    done
    if (( base < 0 )); then
        printf 'encounter_tier_shift: bad tier %s\n' "$tier" >&2
        return 1
    fi
    target=$(( base + steps ))
    (( target > 3 )) && target=3
    printf '%s' "${ENCOUNTER_TIERS[$target]}"
}

encounter_natures_list() {
    local body
    body="$(pokeapi_get "nature?limit=100")" || return 1
    jq -r '.results[].name' <<< "$body"
}

# Print 6 space-separated floats: nature_mod for hp atk def spa spd spe.
encounter_nature_mods() {
    local nature="$1"
    local nat
    nat="$(pokeapi_get "nature/$nature")" || return 1
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
    # Allocate in chunks of 4 (one chunk = +1 effective stat point).
    while (( remaining >= 4 )); do
        (( guard++ > 10000 )) && break
        local i=$((RANDOM % 6))
        local headroom=$((252 - evs[i]))
        (( headroom < 4 )) && {
            local all=1 j
            for j in "${evs[@]}"; do (( j < 252 )) && { all=0; break; }; done
            (( all )) && break
            continue
        }
        local cap_chunks=$((headroom / 4))
        local rem_chunks=$((remaining / 4))
        (( cap_chunks > rem_chunks )) && cap_chunks=$rem_chunks
        local delta_chunks=$(( (RANDOM % cap_chunks) + 1 ))
        local delta=$((delta_chunks * 4))
        evs[i]=$((evs[i] + delta))
        remaining=$((remaining - delta))
    done
    # 510 is not a multiple of 4: drop the 1-3 leftover on a stat with room
    # (matches in-game behavior — last bits are wasted but the total is preserved).
    if (( remaining > 0 )); then
        local tries=0 i
        while (( tries < 100 )); do
            i=$((RANDOM % 6))
            if (( evs[i] + remaining <= 252 )); then
                evs[i]=$((evs[i] + remaining))
                break
            fi
            (( tries++ ))
        done
    fi
    printf '%s' "${evs[*]}"
}

encounter_roll_level() {
    local lo="$1" hi="$2"
    local span=$((hi - lo + 1))
    printf '%d' "$((lo + RANDOM % span))"
}

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
        if [[ -z "$base" || "$base" == "null" ]]; then
            printf 'encounter_compute_all_stats: missing base for %s\n' "$stat" >&2
            return 1
        fi
        out+=("$(encounter_compute_stat "$stat" "$base" "${ivs[$i]}" "${evs[$i]}" "$level" "${mods[$i]}")")
    done
    printf '%s' "${out[*]}"
}

# Roll an ability. Prints JSON {name, is_hidden}.
encounter_roll_ability() {
    local species="$1"
    local poke
    poke="$(pokeapi_get "pokemon/$species")" || return 1
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

# Roll up to 4 moves from union of (level-up + machine + egg + tutor) where
# level_learned_at <= level. Prints JSON array of move-name strings.
encounter_roll_moves() {
    local species="$1" level="$2"
    local poke
    poke="$(pokeapi_get "pokemon/$species")" || return 1

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

encounter_roll_gender() {
    local species="$1"
    local spec
    spec="$(pokeapi_get "pokemon-species/$species")" || return 1
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
    local p
    p="$(encounter_pool_path "$biome_id")"
    [[ -f "$p" ]] || { printf 'null'; return; }
    local berries n idx
    mapfile -t berries < <(jq -r '.berries[]?' "$p")
    n="${#berries[@]}"
    (( n > 0 )) || { printf 'null'; return; }
    idx=$((RANDOM % n))
    printf '%s' "${berries[$idx]}"
}

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

# encounter_build_pool <biome_id>
# Emits a JSON object {tiers:{common:[],uncommon:[],rare:[],very_rare:[]}}
# where every entry is {species, min, max} (no pct). Type-derived: union
# species across biome.types[], filter out legendaries/mythicals,
# tier by capture_rate, expand evolution chain stages, dedup.
encounter_build_pool() {
    local biome_id="$1"
    if ! command -v biome_types_for > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi

    # 1. Union species across biome.types[].
    local types_list species_union='[]'
    types_list="$(biome_types_for "$biome_id")" || return 1
    local t
    while IFS= read -r t; do
        [[ -z "$t" ]] && continue
        local type_body
        type_body="$(pokeapi_get "type/$t")" || return 1
        species_union="$(jq -c --argjson e "$(jq -c '[.pokemon[].pokemon.name]' <<< "$type_body")" \
            '. + $e | unique' <<< "$species_union")"
    done <<< "$types_list"

    # 2. For each species: filter legendary/mythical; classify by capture_rate.
    local base='[]'
    local sp
    while IFS= read -r sp; do
        [[ -z "$sp" ]] && continue
        local spec
        spec="$(pokeapi_get "pokemon-species/$sp" 2>/dev/null)" || continue
        local is_leg is_myth cr
        is_leg="$(jq -r '.is_legendary // false' <<< "$spec")"
        is_myth="$(jq -r '.is_mythical // false' <<< "$spec")"
        [[ "$is_leg" == "true" || "$is_myth" == "true" ]] && continue
        cr="$(jq -r '.capture_rate // 45' <<< "$spec")"
        local tier tier_idx
        tier="$(encounter_tier_for_capture_rate "$cr")"
        tier_idx=-1
        local i
        for i in 0 1 2 3; do
            [[ "${ENCOUNTER_TIERS[$i]}" == "$tier" ]] && tier_idx=$i && break
        done
        base="$(jq -c --arg sp "$sp" --argjson ti "$tier_idx" \
            '. + [{species:$sp, tier_idx:$ti}]' <<< "$base")"
    done < <(jq -r '.[]' <<< "$species_union")

    # 3. Walk evolution chain per root species: expand stages, shift tier.
    local flat='[]'
    local n
    n="$(jq 'length' <<< "$base")"
    local seen_chains='[]'
    for (( i=0; i<n; i++ )); do
        local entry sp tier_idx
        entry="$(jq -c ".[$i]" <<< "$base")"
        sp="$(jq -r '.species' <<< "$entry")"
        tier_idx="$(jq -r '.tier_idx' <<< "$entry")"

        local spec chain_url chain_id
        spec="$(pokeapi_get "pokemon-species/$sp" 2>/dev/null)" || continue
        chain_url="$(jq -r '.evolution_chain.url' <<< "$spec")"
        if [[ -z "$chain_url" || "$chain_url" == "null" ]]; then
            flat="$(jq -c --arg s "$sp" --argjson t "$tier_idx" \
                '. + [{species:$s, min:5, max:15, tier_idx:$t}]' <<< "$flat")"
            continue
        fi
        chain_id="$(basename -- "${chain_url%/}")"

        if jq -e --arg c "$chain_id" 'index($c)' <<< "$seen_chains" > /dev/null; then
            continue
        fi
        seen_chains="$(jq -c --arg c "$chain_id" '. + [$c]' <<< "$seen_chains")"

        local chain stages
        chain="$(pokeapi_get "evolution-chain/$chain_id" 2>/dev/null)" || continue
        stages="$(encounter_walk_chain "$chain")"

        local stage_entries
        stage_entries="$(jq -c \
            --argjson root_idx "$tier_idx" --arg anchor "$sp" --argjson stages "$stages" '
            ($stages | map(.species) | index($anchor)) as $anchor_stage
            | $stages
            | sort_by(.stage_idx)
            | reduce .[] as $s (
                {expanded: [], by_idx: {}};
                ($s.stage_idx - ($anchor_stage // 0)) as $offset
                | (if $s.stage_idx == 0 then 5 else
                       (.by_idx[(($s.stage_idx - 1)|tostring)] // 15) + 1
                   end) as $emin_pre
                | (if $s.min_level_evo != null and $s.stage_idx > 0 then
                       $s.min_level_evo
                   else $emin_pre end) as $emin
                | ($emin + 10) as $emax
                | ([$root_idx + $offset, 3] | map(if . < 0 then 0 else . end) | min) as $tidx
                | .expanded += [{
                    species: $s.species, min: $emin, max: $emax, tier_idx: $tidx
                  }]
                | .by_idx[($s.stage_idx|tostring)] = $emax
              )
            | .expanded
        ' <<< 'null')"
        flat="$(jq -c --argjson e "$stage_entries" '. + $e' <<< "$flat")"
    done

    # 4. Collision dedup: same species in multiple tiers -> keep min tier_idx.
    local deduped
    deduped="$(jq -c '
        group_by(.species)
        | map(
            (min_by(.tier_idx)) as $win
            | {
                species: $win.species,
                min: ([.[] | select(.tier_idx == $win.tier_idx) | .min] | min),
                max: ([.[] | select(.tier_idx == $win.tier_idx) | .max] | max),
                tier_idx: $win.tier_idx
              }
          )
    ' <<< "$flat")"

    # 5. Bucket into tier arrays.
    local tiered
    tiered="$(jq -c --argjson tiers '["common","uncommon","rare","very_rare"]' '
        ($tiers | map({(.) : []}) | add) as $empty
        | reduce .[] as $e ($empty;
            ($tiers[$e.tier_idx]) as $name
            | .[$name] += [{species: $e.species, min: $e.min, max: $e.max}]
          )
    ' <<< "$deduped")"

    # 6. Derive berries by natural_gift_type intersection with biome.types.
    local berries='[]' berry_list
    berry_list="$(pokeapi_get "berry?limit=100" | jq -r '.results[].name')"
    local types_array
    types_array="$(printf '%s\n' $(biome_types_for "$biome_id") | jq -R . | jq -s -c .)"
    local berry
    while IFS= read -r berry; do
        [[ -z "$berry" ]] && continue
        local bj ngt
        bj="$(pokeapi_get "berry/$berry" 2>/dev/null)" || continue
        ngt="$(jq -r '.natural_gift_type.name // ""' <<< "$bj")"
        [[ -z "$ngt" ]] && continue
        if printf '"%s"' "$ngt" | jq -e --argjson types "$types_array" '. as $t | $types | index($t) != null' > /dev/null; then
            berries="$(jq -c --arg b "$berry" '. + [$b]' <<< "$berries")"
        fi
    done <<< "$berry_list"

    jq -c -n --argjson tiers "$tiered" --argjson berries "$berries" \
        '{tiers: $tiers, berries: $berries}'
}

encounter_pool_path() {
    local biome="$1"
    printf '%s/pools/%s.json' "${POKIDLE_CACHE_DIR:-$HOME/.cache/pokidle}" "$biome"
}

encounter_pool_save() {
    local biome="$1" body_json="$2"
    local p
    p="$(encounter_pool_path "$biome")"
    mkdir -p -- "$(dirname -- "$p")"
    local body
    body="$(jq -c -n --arg b "$biome" --arg ts "$(date -u +%FT%TZ)" \
                  --argjson p "$body_json" '{
        biome: $b,
        built_at: $ts,
        schema: 3,
        tiers: $p.tiers,
        berries: ($p.berries // [])
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

# Roll a pool entry from a v2 pool {schema:2, tiers:{...}}.
# Pick a tier by fixed weights, walk forward to the next non-empty tier on
# empty bucket, then pick uniformly inside. Errors out if every tier empty.
encounter_roll_pool_entry() {
    local pool="$1"
    local roll=$((RANDOM % 100))
    local cum=0 i tier_idx=0 step name n arr_idx
    for i in 0 1 2 3; do
        cum=$(( cum + ENCOUNTER_TIER_ROLL_WEIGHT[i] ))
        if (( roll < cum )); then
            tier_idx=$i
            break
        fi
    done
    for step in 0 1 2 3; do
        name="${ENCOUNTER_TIERS[$(( (tier_idx + step) % 4 ))]}"
        n="$(jq --arg t "$name" '.tiers[$t] | length' <<< "$pool")"
        if (( n > 0 )); then
            arr_idx=$(( RANDOM % n ))
            jq -c --arg t "$name" --argjson i "$arr_idx" '.tiers[$t][$i]' <<< "$pool"
            return 0
        fi
    done
    printf 'encounter_roll_pool_entry: pool has no entries in any tier\n' >&2
    return 1
}

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
    poke="$(pokeapi_get "pokemon/$sp")" || return 1
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

    local natures n nature
    mapfile -t natures < <(encounter_natures_list)
    n="${#natures[@]}"
    nature="${natures[$((RANDOM % n))]}"
    local mods
    mods="$(encounter_nature_mods "$nature")" || return 1

    local ability_obj ability is_hidden
    ability_obj="$(encounter_roll_ability "$sp")" || return 1
    ability="$(jq -r '.name' <<< "$ability_obj")"
    is_hidden="$(jq -r 'if .is_hidden then 1 else 0 end' <<< "$ability_obj")"

    local moves_json
    moves_json="$(encounter_roll_moves "$sp" "$level")" || return 1

    local gender shiny held_berry
    gender="$(encounter_roll_gender "$sp")" || return 1
    shiny="$(encounter_roll_shiny)"
    held_berry="$(encounter_roll_held_berry "$biome")" || return 1

    local base_stats stats
    base_stats="$(jq -c '.stats' <<< "$poke")"
    stats="$(encounter_compute_all_stats "$base_stats" "$ivs" "$evs" "$level" "$mods")" || return 1

    local final_sprite="$sprite_url"
    [[ "$shiny" == "1" && -n "$sprite_url_shiny" ]] && final_sprite="$sprite_url_shiny"

    local friendship
    friendship="$(encounter_roll_friendship "$sp")" || return 1

    local berry_arg
    if [[ "$held_berry" == "null" ]]; then berry_arg="null"; else berry_arg="\"$held_berry\""; fi

    local ivs_json evs_json stats_json
    ivs_json="[$(printf '%s,' $ivs | sed 's/,$//')]"
    evs_json="[$(printf '%s,' $evs | sed 's/,$//')]"
    stats_json="[$(printf '%s,' $stats | sed 's/,$//')]"

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
}

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

# encounter_roll_item <biome_id>
# Emits {"item": "<name>", "sprite_url": "<url|empty>"}.
encounter_roll_item() {
    local biome_id="$1"
    if ! command -v biome_types_for > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi
    local types_list pool=() seen=""
    types_list="$(biome_types_for "$biome_id")" || return 1
    local t item
    while IFS= read -r t; do
        [[ -z "$t" ]] && continue
        for item in ${ENCOUNTER_HELD_ITEMS_BY_TYPE[$t]:-}; do
            [[ "$seen" == *"|$item|"* ]] && continue
            pool+=("$item")
            seen+="|$item|"
        done
    done <<< "$types_list"
    for item in "${ENCOUNTER_HELD_ITEMS_GENERIC[@]}"; do
        [[ "$seen" == *"|$item|"* ]] && continue
        pool+=("$item")
        seen+="|$item|"
    done
    local n="${#pool[@]}"
    (( n > 0 )) || { printf 'encounter_roll_item: empty pool for biome %s\n' "$biome_id" >&2; return 1; }
    local idx=$((RANDOM % n))
    local name="${pool[$idx]}"
    local item_json sprite
    item_json="$(pokeapi_get "item/$name")" || return 1
    sprite="$(jq -r '.sprites.default // ""' <<< "$item_json")"
    jq -n --arg item "$name" --arg sprite "$sprite" '{item: $item, sprite_url: $sprite}'
}
