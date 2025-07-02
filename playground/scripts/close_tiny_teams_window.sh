#!/usr/bin/env bash

function main() {
    local size window windows
    mapfile -t windows < <(xdotool search teams.live.com__v2 2> /dev/null)
    for window in "${windows[@]}"; do
        mapfile -t size < <(xdotool getwindowgeometry "${window}" | awk '/^ +Geometry:/ {print $2}' | tr x '\n')

        if (( size[0] < 500 )) && (( size[1] < 500 )); then
            xdotool windowclose "${window}"
        fi
    done
}

main

