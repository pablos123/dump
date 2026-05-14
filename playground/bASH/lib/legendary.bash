#!/usr/bin/env bash
# lib/legendary.bash — static legendary roster + roll helper.

declare -ga LEGENDARY_SPECIES=(
    # Gen 1
    articuno zapdos moltres mewtwo mew
    # Gen 2
    raikou entei suicune lugia ho-oh celebi
    # Gen 3
    regirock regice registeel latias latios kyogre groudon
    rayquaza jirachi deoxys
    # Gen 4
    uxie mesprit azelf dialga palkia heatran regigigas giratina
    cresselia phione manaphy darkrai shaymin arceus
    # Gen 5
    victini cobalion terrakion virizion tornadus thundurus reshiram
    zekrom landorus kyurem keldeo meloetta genesect
    # Gen 6
    xerneas yveltal zygarde diancie hoopa volcanion
    # Gen 7
    type-null silvally tapu-koko tapu-lele tapu-bulu tapu-fini
    cosmog cosmoem solgaleo lunala nihilego buzzwole pheromosa
    xurkitree celesteela kartana guzzlord necrozma magearna
    marshadow poipole naganadel stakataka blacephalon zeraora
    meltan melmetal
    # Gen 8
    zacian zamazenta eternatus kubfu urshifu zarude regieleki
    regidrago glastrier spectrier calyrex
)

legendary_roll_species() {
    local n="${#LEGENDARY_SPECIES[@]}"
    (( n > 0 )) || { printf 'legendary_roll_species: empty roster\n' >&2; return 1; }
    printf '%s' "${LEGENDARY_SPECIES[$((RANDOM % n))]}"
}

# legendary_build_encounter <species> <biome_id>
# Emits a JSON encounter object ready for db_insert_encounter (after
# adding session_id, encountered_at, sprite_path). Always sets
# .is_legendary=true and .held_berry=null.
legendary_build_encounter() {
    local sp="$1" biome="$2"
    if ! command -v encounter_natures_list > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/encounter.bash"
    fi
    local poke
    poke="$(pokeapi_get "pokemon/$sp")" || return 1
    local dex_id sprite_url sprite_url_shiny
    dex_id="$(jq -r '.id' <<< "$poke")"
    sprite_url="$(jq -r '.sprites.front_default // ""' <<< "$poke")"
    sprite_url_shiny="$(jq -r '.sprites.front_shiny // ""' <<< "$poke")"

    local lo="${POKIDLE_LEGENDARY_LEVEL_MIN:-50}"
    local hi="${POKIDLE_LEGENDARY_LEVEL_MAX:-70}"
    local level ivs evs
    level="$(encounter_roll_level "$lo" "$hi")"
    ivs="$(encounter_roll_ivs)"
    evs="$(encounter_ev_split "$((RANDOM % 511))")"

    local natures n nature mods
    mapfile -t natures < <(encounter_natures_list)
    n="${#natures[@]}"
    nature="${natures[$((RANDOM % n))]}"
    mods="$(encounter_nature_mods "$nature")" || return 1

    local ability_obj ability is_hidden
    ability_obj="$(encounter_roll_ability "$sp")" || return 1
    ability="$(jq -r '.name' <<< "$ability_obj")"
    is_hidden="$(jq -r 'if .is_hidden then 1 else 0 end' <<< "$ability_obj")"

    local moves_json gender shiny
    moves_json="$(encounter_roll_moves "$sp" "$level")" || return 1
    gender="$(encounter_roll_gender "$sp")" || return 1
    shiny="$(encounter_roll_shiny)"

    local friendship
    friendship="$(encounter_roll_friendship "$sp")" || return 1

    local base_stats stats
    base_stats="$(jq -c '.stats' <<< "$poke")"
    stats="$(encounter_compute_all_stats "$base_stats" "$ivs" "$evs" "$level" "$mods")" || return 1

    local final_sprite="$sprite_url"
    [[ "$shiny" == "1" && -n "$sprite_url_shiny" ]] && final_sprite="$sprite_url_shiny"

    local ivs_json evs_json stats_json
    ivs_json="[$(printf '%s,' $ivs | sed 's/,$//')]"
    evs_json="[$(printf '%s,' $evs | sed 's/,$//')]"
    stats_json="[$(printf '%s,' $stats | sed 's/,$//')]"

    jq -n \
        --arg sp "$sp" --argjson dex "$dex_id" --argjson lvl "$level" \
        --arg nature "$nature" --arg ability "$ability" --argjson hidden "$is_hidden" \
        --arg gender "$gender" --argjson shiny "$shiny" \
        --argjson friendship "$friendship" \
        --argjson ivs "$ivs_json" --argjson evs "$evs_json" --argjson stats "$stats_json" \
        --argjson moves "$moves_json" --arg sprite "$final_sprite" '{
            species: $sp, dex_id: $dex, level: $lvl,
            nature: $nature, ability: $ability, is_hidden_ability: $hidden,
            gender: $gender, shiny: $shiny, held_berry: null,
            friendship: $friendship,
            ivs: $ivs, evs: $evs, stats: $stats,
            moves: $moves, sprite_url: $sprite,
            is_legendary: true
        }'
}
