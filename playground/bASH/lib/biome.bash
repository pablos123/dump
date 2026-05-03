#!/usr/bin/env bash
# lib/biome.bash — biome config loader, classifier, rotation.

biome_config_path() {
    local p
    if [[ -n "${POKIDLE_CONFIG_DIR:-}" && -f "${POKIDLE_CONFIG_DIR}/biomes.json" ]]; then
        p="${POKIDLE_CONFIG_DIR}/biomes.json"
    elif [[ -n "${POKIDLE_REPO_ROOT:-}" && -f "${POKIDLE_REPO_ROOT}/config/biomes.json" ]]; then
        p="${POKIDLE_REPO_ROOT}/config/biomes.json"
    else
        printf 'biome_config_path: cannot find biomes.json\n' >&2
        return 1
    fi
    printf '%s' "$p"
}

biome_load() {
    local p
    p="$(biome_config_path)" || return 1
    cat "$p"
}

biome_get() {
    local id="$1"
    local out
    out="$(biome_load | jq --arg id "$id" '.biomes[] | select(.id==$id)')"
    [[ -n "$out" ]] || { printf 'biome_get: unknown biome %s\n' "$id" >&2; return 1; }
    printf '%s' "$out"
}

biome_ids() {
    biome_load | jq -r '.biomes[].id'
}

biome_validate() {
    local cfg
    cfg="$(biome_load)" || return 1

    # Required top-level shape
    if ! jq -e 'has("biomes") and has("fallback_biome")' <<< "$cfg" > /dev/null; then
        printf 'biome_validate: missing biomes or fallback_biome\n' >&2
        return 1
    fi

    # All biome objects have required keys
    local missing
    missing="$(jq -r '
        .biomes[] |
        select(
            (has("id")|not) or (has("label")|not) or
            (has("name_regex")|not) or (has("type_affinity")|not) or
            (has("berry_pool")|not) or (has("item_pool")|not)
        ) | .id // "<no-id>"
    ' <<< "$cfg")"
    if [[ -n "$missing" ]]; then
        printf 'biome_validate: biomes missing keys: %s\n' "$missing" >&2
        return 1
    fi

    # Duplicate ids
    local dupes
    dupes="$(jq -r '.biomes | group_by(.id) | map(select(length>1) | .[0].id) | .[]' <<< "$cfg")"
    if [[ -n "$dupes" ]]; then
        printf 'biome_validate: duplicate biome ids: %s\n' "$dupes" >&2
        return 1
    fi

    # Fallback biome must exist
    local fb
    fb="$(jq -r '.fallback_biome' <<< "$cfg")"
    if ! jq -e --arg fb "$fb" '.biomes[] | select(.id==$fb)' <<< "$cfg" > /dev/null; then
        printf 'biome_validate: fallback_biome "%s" not in biomes\n' "$fb" >&2
        return 1
    fi

    return 0
}

# Compute the union of types of every pokemon listed in an area's encounters.
# Echoes one type-name per line.
_biome_area_types() {
    local area_json="$1"
    local species
    species="$(jq -r '.pokemon_encounters[].pokemon.name' <<< "$area_json")"
    local s types
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        types="$(pokeapi_get "pokemon/$s" | jq -r '.types[].type.name')"
        printf '%s\n' $types
    done <<< "$species" | sort -u
}

# Classify a /location-area JSON to a biome id.
# Algorithm: name_regex match = +10, count of intersecting types in type_affinity
# adds to score. Highest scoring biome wins; on tie, first match by config order.
biome_classify_area() {
    local area_json="$1"
    local cfg
    cfg="$(biome_load)" || return 1
    local area_name
    area_name="$(jq -r '.name' <<< "$area_json")"

    local area_types_list
    area_types_list="$(_biome_area_types "$area_json")"

    local best_id="" best_score=0
    local i count
    count="$(jq '.biomes | length' <<< "$cfg")"

    for ((i=0; i<count; i++)); do
        local id regex affinity
        id="$(jq -r ".biomes[$i].id" <<< "$cfg")"
        regex="$(jq -r ".biomes[$i].name_regex" <<< "$cfg")"
        affinity="$(jq -r ".biomes[$i].type_affinity[]?" <<< "$cfg")"

        local score=0
        local pat="$regex"
        local flags="-E"
        if [[ "$pat" == *"(?i)"* ]]; then
            pat="${pat//'(?i)'/}"
            flags="-Ei"
        fi
        if [[ -n "$pat" ]] && grep $flags -q "$pat" <<< "$area_name"; then
            score=$((score + 10))
        fi
        local t
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            if grep -Fxq "$t" <<< "$area_types_list"; then
                score=$((score + 1))
            fi
        done <<< "$affinity"

        if (( score > best_score )); then
            best_score=$score
            best_id="$id"
        fi
    done

    if (( best_score == 0 )); then
        jq -r '.fallback_biome' <<< "$cfg"
    else
        printf '%s' "$best_id"
    fi
}

biome_pick_random() {
    local ids n idx
    mapfile -t ids < <(biome_ids)
    n="${#ids[@]}"
    (( n > 0 )) || { printf 'biome_pick_random: no biomes\n' >&2; return 1; }
    idx=$((RANDOM % n))
    printf '%s' "${ids[$idx]}"
}

biome_pick_random_excluding() {
    local exclude="$1"
    local ids filtered idx n
    mapfile -t ids < <(biome_ids)
    filtered=()
    local id
    for id in "${ids[@]}"; do
        [[ "$id" != "$exclude" ]] && filtered+=("$id")
    done
    n="${#filtered[@]}"
    (( n > 0 )) || { printf 'biome_pick_random_excluding: no eligible biome\n' >&2; return 1; }
    idx=$((RANDOM % n))
    printf '%s' "${filtered[$idx]}"
}
