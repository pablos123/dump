#!/usr/bin/env bash

# Part 1

total_paper=0

while read -r input_line; do
    mapfile -t gift_measures_arr < <(echo "${input_line}" | tr 'x' '\n')

    l="${gift_measures_arr[0]}"
    w="${gift_measures_arr[1]}"
    h="${gift_measures_arr[2]}"

    (( m = l * w ))

    if (( w * h < m )); then
        (( m = w * h ))
    fi

    if (( h * l < m )); then
        (( m = h * l ))
    fi

    (( total_paper += 2*l*w + 2*w*h + 2*h*l + m ))

done < "./inputs/2.txt"

echo "Total paper is: ${total_paper}"

# Part 2

total_ribbon=0

while read -r input_line; do
    mapfile -t gift_measures_arr < <(echo "${input_line}" | tr 'x' '\n')

    l="${gift_measures_arr[0]}"
    w="${gift_measures_arr[1]}"
    h="${gift_measures_arr[2]}"

    (( m = l + w ))

    if (( w + h < m )); then
        (( m = w + h ))
    fi

    if (( h + l < m )); then
        (( m = h + l ))
    fi

    (( total_ribbon += l*w*h + 2 * m ))

done < "./inputs/2.txt"

echo "Total ribbon is: ${total_ribbon}"
