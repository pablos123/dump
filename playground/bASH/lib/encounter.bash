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
