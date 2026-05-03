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
