#!/usr/bin/env python3

from colors import ColorUtils


def tests():
    print("Testing color utils")

    color_utils = ColorUtils()

    assert color_utils.hex_to_rgb("#4287f5") == (66, 135, 245)
    assert color_utils.rgb_to_hex((66, 135, 245)) == "#4287f5"
    assert color_utils.hex_to_ansi("#4287f5") == "\\033[38;2;66;135;245m"
    assert color_utils.rgb_to_ansi((66, 135, 245)) == "\\033[38;2;66;135;245m"

    print("All passed!")


if __name__ == "__main__":
    tests()
