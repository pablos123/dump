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
