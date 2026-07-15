#!/usr/bin/env bash

# Part 1
up_floors=$(rg --count-matches '\(' ./inputs/1.txt)
down_floors=$(rg --count-matches '\)' ./inputs/1.txt)

echo "The floor Santa needs to be is: $(( up_floors - down_floors ))"

# Part 2
mapfile -t all_chars < <(sed 's/\(.\)/\1\n/g' inputs/1.txt)

sum=0
for i in "${!all_chars[@]}"; do
    char="${all_chars[i]}"
    case ${char} in
        '(') (( sum++ )) ;;
        ')') (( sum-- )) ;;
    esac
    if (( sum < 0 )); then
        echo "The first time Santa goes to the basement is: $(( i + 1 ))"
        exit 0
    fi
done
