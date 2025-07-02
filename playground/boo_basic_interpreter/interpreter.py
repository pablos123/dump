#!/bin/python3

# Stupid interpreter for useless mathematics
# Just for understanding https://homepages.cwi.nl/~aeb/std/hashexclam-1.html

import sys
import os


def sum_call():
    pass


def diff_call():
    pass


def mult_call():
    pass


def div_call():
    pass


def boo_call():
    pass


def r_call():
    pass


def p_call():
    pass


ops = {
    "sum": sum_call,
    "diff": diff_call,
    "mult": mult_call,
    "div": div_call,
    "boo": boo_call,
    "r": r_call,
    "p": p_call,
}


def intepreter(argv: list):
    file_path = ""
    if len(argv) == 2:
        file_path = argv[1]
    elif len(argv) > 2:
        file_path = argv[2]
    assert os.path.isfile(file_path)

    lines = []
    with open(file_path, "r") as f:
        lines = f.readlines()

    result = 0
    for c, line in enumerate(lines):
        sl = line.split()

        if not sl or sl[0].startswith("#"):
            continue

        op = ops.get(sl[0])
        if not op:
            print(f"Error: invalid operation in line {c}")
            continue

        local_r: float = 0
        try:
            cs = sl.index("#")
        except ValueError:
            cs = -1

        operands = sl[1:cs]

        try:
            local_r = op(*[float(s) for s in operands[1:2]])
        except ZeroDivisionError:
            pass

        for s in sl[3:]:
            local_r = op(local_r, float(s))
        result += local_r

    print(result)


if __name__ == "__main__":
    intepreter(sys.argv)
