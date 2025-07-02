#!/usr/bin/env bash

sed -e '/./!Q' ./inputs/5.txt > /tmp/order_needed_advent_of_code_5.tmp

mapfile -t manual_printings_arr < <(tac ./inputs/5.txt | sed -e '/./!Q')


# Part 1

total_sum_correct=0
for manual_print in "${manual_printings_arr[@]}"; do
    mapfile -t manual_print_arr < <(echo "${manual_print}" | tr ',' '\n')
    mapfile -t manual_print_reverse_arr < <(echo "${manual_print}" | tr ',' '\n' | tac)

    bad_format=false
    for page_rev in "${manual_print_reverse_arr[@]}"; do
        for page in "${manual_print_arr[@]}"; do
            if (( page_rev == page )); then
                break
            fi

            if rg -q "${page_rev}\|${page}" /tmp/order_needed_advent_of_code_5.tmp; then
                bad_format=true
                break
            fi
        done
        if ${bad_format}; then
            break
        fi
    done

    if ! ${bad_format}; then
        middle_page=$(( ${#manual_print_arr[@]} / 2 ))
        (( total_sum_correct += manual_print_arr[middle_page] ))
    fi
done

echo "Total sum of correct middle pages: ${total_sum_correct}"


# Part 2


total_sum_incorrect=0
for manual_print in "${manual_printings_arr[@]}"; do
    mapfile -t manual_print_arr < <(echo "${manual_print}" | tr ',' '\n')

    bad_format=false
    current_bad=false

    manual_print_arr_len=${#manual_print_arr[@]}

    for (( i = 0; i < manual_print_arr_len; ++i )); do
        # Check again the same index if failed
        if ${current_bad}; then
            (( --i ))
        fi

        current_bad=false
        page_check_i=${manual_print_arr[i]}

        for (( j = i + 1; j < manual_print_arr_len; ++j )); do
            page_check_j=${manual_print_arr[j]}
            if rg -q "${page_check_j}\|${page_check_i}" /tmp/order_needed_advent_of_code_5.tmp; then
                swap_index=${j}
                swap_value=${page_check_j}
                current_bad=true
            fi
        done
        if ${current_bad}; then
            manual_print_arr[swap_index]=${manual_print_arr[i]}
            manual_print_arr[i]=${swap_value}
            bad_format=true
        fi
    done

    if ${bad_format}; then
        middle_page=$(( manual_print_arr_len / 2 ))
        (( total_sum_incorrect += manual_print_arr[middle_page] ))
    fi

done

echo "Total sum of corrected middle pages: ${total_sum_incorrect}"
