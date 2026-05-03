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
