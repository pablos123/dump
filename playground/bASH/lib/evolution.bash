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

# PokeAPI evolution_details.gender code -> encounter gender label.
# Canonical PokeAPI: 1=female, 2=male, 3=genderless. Empty for "no requirement".
_evolution_gender_required() {
    local code="$1"
    case "$code" in
        1) printf 'F' ;;
        2) printf 'M' ;;
        3) printf 'genderless' ;;
        *) printf '' ;;
    esac
}

# Returns "day" or "night" based on local hour. 6:00-17:59 = day; else night.
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

    # known_move_type - encounter.moves are names, not types; cannot verify.
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
# Returns item name (kebab-case) or empty.
evolution_path_item_name() {
    local evo="$1"
    jq -r '.item.name // .held_item.name // empty' <<< "$evo"
}
