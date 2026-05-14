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
