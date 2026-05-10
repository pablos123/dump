#!/usr/bin/env bash
# lib/notify.bash — notify-send + sound playback.

_titlecase() {
    local s="$1"
    printf '%s' "${s^}"
}

_titlecase_words() {
    local s="$1"
    s="${s//-/ }"
    local out=""
    local w
    for w in $s; do
        out+="${w^} "
    done
    printf '%s' "${out% }"
}

_emit() {
    local title="$1"
    local body="$2"
    local urgency="$3"
    local icon="$4"
    if [[ "${POKIDLE_NO_NOTIFY:-0}" == "1" ]]; then
        printf 'TITLE: %s\nBODY: %s\nURGENCY: %s\nICON: %s\n' "$title" "$body" "$urgency" "$icon"
        return 0
    fi
    local args=(-u "$urgency")
    [[ -n "$icon" ]] && args+=(-i "$icon")
    args+=(-h "string:desktop-entry:pokidle")
    notify-send "${args[@]}" "$title" "$body" || \
        printf 'notify-send failed (non-fatal)\n' >&2
}

_play_sound() {
    local kind="$1"
    [[ "${POKIDLE_NO_SOUND:-0}" == "1" ]] && return 0
    local policy="${POKIDLE_SOUND:-shiny}"
    case "$policy" in
        never) return 0 ;;
        shiny) [[ "$kind" == "shiny" ]] || return 0 ;;
        always) ;;
        *) return 0 ;;
    esac
    local file="${POKIDLE_SOUND_ENCOUNTER:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/encounter.ogg}"
    [[ "$kind" == "shiny" ]] && file="${POKIDLE_SOUND_SHINY:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/shiny.ogg}"
    [[ -f "$file" ]] || return 0
    if   command -v paplay >/dev/null; then paplay "$file" >/dev/null 2>&1 &
    elif command -v aplay  >/dev/null; then aplay  -q "$file" >/dev/null 2>&1 &
    fi
}

notify_pokemon() {
    local enc="$1"
    local species level nature ability gender shiny held biome_label
    species="$(jq -r '.species' <<< "$enc")"
    level="$(jq -r '.level' <<< "$enc")"
    nature="$(jq -r '.nature' <<< "$enc")"
    ability="$(jq -r '.ability' <<< "$enc")"
    gender="$(jq -r '.gender' <<< "$enc")"
    shiny="$(jq -r '.shiny' <<< "$enc")"
    held="$(jq -r '.held_berry // ""' <<< "$enc")"
    biome_label="$(jq -r '.biome_label // ""' <<< "$enc")"

    local stats moves
    stats="$(jq -r '.stats | "HP \(.[0])  Atk \(.[1])  Def \(.[2])  SpA \(.[3])  SpD \(.[4])  Spe \(.[5])"' <<< "$enc")"
    moves="$(jq -r '.moves | join(", ")' <<< "$enc")"

    local sp_title nat_title abil_title
    sp_title="$(_titlecase_words "$species")"
    nat_title="$(_titlecase "$nature")"
    abil_title="$(_titlecase_words "$ability")"

    local title body urgency icon
    if [[ "$shiny" == "1" ]]; then
        title="[SHINY ✨] Lv.$level $sp_title"
        urgency="${POKIDLE_NOTIFY_URGENCY_SHINY:-critical}"
    else
        title="Lv.$level $sp_title"
        urgency="normal"
    fi
    body="$biome_label  ·  $nat_title  ·  $abil_title"$'\n'"$stats"$'\n'"Moves: $moves"
    [[ -n "$held" && "$held" != "null" ]] && body+=$'\n'"Held: $held"

    icon="$(jq -r '.sprite_path // ""' <<< "$enc")"

    _emit "$title" "$body" "$urgency" "$icon"
    if [[ "$shiny" == "1" ]]; then
        _play_sound shiny
    else
        _play_sound encounter
    fi
}

notify_item() {
    local item_json="$1"
    local name biome_label icon
    name="$(jq -r '.item' <<< "$item_json")"
    biome_label="$(jq -r '.biome_label // ""' <<< "$item_json")"
    icon="$(jq -r '.sprite_path // ""' <<< "$item_json")"
    local title body
    title="Found $(_titlecase_words "$name")"
    body="$biome_label  ·  held-item"
    _emit "$title" "$body" "low" "$icon"
}

notify_evolution() {
    local evo_json="$1"
    local from to biome_label icon
    from="$(jq -r '.from' <<< "$evo_json")"
    to="$(jq -r '.to' <<< "$evo_json")"
    biome_label="$(jq -r '.biome_label // ""' <<< "$evo_json")"
    icon="$(jq -r '.sprite_path // ""' <<< "$evo_json")"

    local from_t to_t title body
    from_t="$(_titlecase_words "$from")"
    to_t="$(_titlecase_words "$to")"
    title="$from_t evolved into $to_t"
    body="$biome_label"

    _emit "$title" "$body" "normal" "$icon"
    _play_sound encounter
}

notify_biome_change() {
    local label="$1" pool_size="$2" item_count="$3"
    local title="Biome changed → $label"
    local body="Encounters: $pool_size species, $item_count items"
    _emit "$title" "$body" "low" ""
}
