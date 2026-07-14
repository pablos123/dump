#!/usr/bin/env python3
# Deps: none (stdlib only)
import random

# This is not it. The <p> tag has not a fixed size in the page.
# I just did it by hand.
web_bio_len = 26
level_len = web_bio_len * 4
space="⠀"

# Types
fish = [ "𓆝", "𓆟", "𓆞", "𓆟"]
sea = [ "𓆝", "𓆟", "𓆞", "𓆟", "𓆉", "𓇼"]
chaos = ["𒈔", "𒅒", "𒇫", "𒄆"]
columns1 = ["▁", "▂", "▃", "▄", "▅", "▆", "▇"]
columns2 = ["░", "▒", "▓", "■", "▀", "▄"]
columns3 = ["░", "▒", "▓", "■", "▀", "▁", "▂", "▃", "▄", "▅", "▆", "▇" ]


def sea_to_chaos():
    bio = "...﹏𓊝﹏𓂁﹏...\n"
    for _ in range(7):
        for _ in range(web_bio_len):
            bio=f"{bio}{space} "

        bio=f"{bio}{space}\n"

    for _ in range(level_len):
        char = random.choice(fish)
        bio=f"{bio}{char}{space}"

    for _ in range(level_len):
        char = random.choice(sea)
        bio=f"{bio}{char}{space}"

    for _ in range(level_len):
        char = random.choice(columns1)
        bio=f"{bio}{char}{space}"

    for _ in range(level_len):
        char = random.choice(columns2)
        bio=f"{bio}{char}{space}"

    for _ in range(level_len * 2):
        char = random.choice(chaos)
        bio=f"{bio}{char}"

    print(f"{bio}", end="")

def columns():
    bio = "░"
    for _ in range(7):
        for _ in range(int(web_bio_len / 2) - 1):
            bio=f"{bio}{space} "
        bio=f"{bio}{space} \n"

    for _ in range(level_len * 14):
        char = random.choice(columns3)
        bio=f"{bio}{char}"

    print(bio, end="")

def columns_with_spaces():
    bio = "░"
    for _ in range(7):
        for _ in range(web_bio_len):
            bio=f"{bio}{space} "
        bio=f"{bio}{space}\n"

    for _ in range(level_len * 14):
        char = random.choice(columns3)
        bio=f"{bio}{char}{space}"

    print(bio, end="")


if __name__ == "__main__":
    print("\n\nSEA TO CHAOS\n")
    sea_to_chaos()
    print("\n\nCOLUMNS WITH SPACES\n")
    columns_with_spaces()
    print("\n\nCOLUMNS\n")
    columns()
    print("\n\n")

