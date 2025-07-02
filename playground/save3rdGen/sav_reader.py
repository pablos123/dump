#!/bin/python3

import argparse
import struct

def main():
    parser = argparse.ArgumentParser(
                        prog="save3RDGen!",
                        description="Show information from a .SAV file of a 3rd gen Pokemon game.",
                        epilog="")
    parser.add_argument("filename")
    args = parser.parse_args()

    with open(args.filename, mode='rb') as file:
        fileContent = file.read()
        hex_content = file.read().encode('hex')
        print(hex_content)
        number_of_bytes = "I" * (len(fileContent) // 4)
        starts = struct.unpack(number_of_bytes, fileContent)
        # print(starts)
        # print(body)
        # print(end)


if __name__ == "__main__":
    main()