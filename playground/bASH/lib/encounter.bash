#!/usr/bin/env bash
# lib/encounter.bash — pool build, evo expansion, rolls, stat formulas.
# Depends on pokeapi_get from lib/api.bash.

# All 6 stats in canonical order.
ENCOUNTER_STATS=(hp attack defense special-attack special-defense speed)

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
    while (( remaining > 0 )); do
        (( guard++ > 10000 )) && break
        local i=$((RANDOM % 6))
        local headroom=$((252 - evs[i]))
        (( headroom <= 0 )) && {
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
    if ! command -v biome_get > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi
    local biome
    biome="$(biome_get "$biome_id")" || return 1
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

    local raw='[]'
    local area
    while IFS= read -r area; do
        [[ -z "$area" ]] && continue
        local area_json
        area_json="$(pokeapi_get "location-area/$area")" || return 1
        local rows
        rows="$(jq -c '
            .pokemon_encounters[] |
            .pokemon.name as $sp |
            .version_details[] |
            .version.name as $ver |
            .encounter_details[] |
            {species: $sp, min: .min_level, max: .max_level, chance: .chance, version: $ver}
        ' <<< "$area_json")"
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

    local base
    base="$(jq -c '
        group_by(.species) | map({
            species: (.[0].species),
            min: ([.[].min] | min),
            max: ([.[].max] | max),
            pct: ([.[].chance] | add)
        })
    ' <<< "$raw")"

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

        local spec chain_url chain_id
        spec="$(pokeapi_get "pokemon-species/$sp")" || return 1
        chain_url="$(jq -r '.evolution_chain.url' <<< "$spec")"
        chain_id="$(basename -- "${chain_url%/}")"

        local chain stages
        chain="$(pokeapi_get "evolution-chain/$chain_id")" || return 1
        stages="$(encounter_walk_chain "$chain")"

        local new_entries
        new_entries="$(jq -c \
            --argjson root_min "$min" --argjson root_max "$max" --argjson delta "$delta" \
            --argjson root_pct "$pct" \
            --argjson stages "$stages" '
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
        --argjson ivs "$ivs_json" --argjson evs "$evs_json" --argjson stats "$stats_json" \
        --argjson moves "$moves_json" --arg sprite "$final_sprite" '{
            species: $sp, dex_id: $dex, level: $lvl,
            nature: $nature, ability: $ability, is_hidden_ability: $hidden,
            gender: $gender, shiny: $shiny, held_berry: $held,
            ivs: $ivs, evs: $evs, stats: $stats,
            moves: $moves, sprite_url: $sprite
        }'
}

# encounter_roll_item <biome_id>
# Emits {"item": "<name>", "sprite_url": "<url|empty>"}.
encounter_roll_item() {
    local biome_id="$1"
    if ! command -v biome_get > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi
    local biome pool
    biome="$(biome_get "$biome_id")" || return 1
    pool="$(jq -c '.item_pool' <<< "$biome")"
    local n
    n="$(jq 'length' <<< "$pool")"
    if (( n == 0 )); then
        biome="$(biome_get wild)" || return 1
        pool="$(jq -c '.item_pool' <<< "$biome")"
        n="$(jq 'length' <<< "$pool")"
    fi
    (( n > 0 )) || return 1
    local idx=$((RANDOM % n))
    local name
    name="$(jq -r ".[$idx]" <<< "$pool")"
    local item_json
    item_json="$(pokeapi_get "item/$name")" || return 1
    local sprite
    sprite="$(jq -r '.sprites.default // ""' <<< "$item_json")"
    jq -n --arg item "$name" --arg sprite "$sprite" '{item: $item, sprite_url: $sprite}'
}
