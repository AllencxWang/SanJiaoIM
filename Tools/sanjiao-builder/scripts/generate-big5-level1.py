#!/usr/bin/env python3
"""Generate Big5Level1Table.swift from the Python big5-hkscs codec.

Usage:
    python3 Tools/sanjiao-builder/scripts/generate-big5-level1.py \\
        > Tools/sanjiao-builder/Sources/SanJiaoBuilder/Big5Level1Table.swift

Extracts all BMP Han ideographs (U+4E00..U+9FFF) reachable from the Big5
level-1 byte range (first byte 0xA4..0xC6). Uses the big5-hkscs codec because
Python's plain big5 codec lacks many HKSCS additions; the resulting 5421
entries are a superset of classic Big5 level-1's 5401 entries.
"""

import codecs

def main() -> None:
    codes: set[int] = set()
    for b1 in range(0xA4, 0xC7):
        for b2 in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            try:
                ch = bytes([b1, b2]).decode("big5-hkscs")
            except UnicodeDecodeError:
                continue
            if len(ch) == 1:
                cp = ord(ch)
                if 0x4E00 <= cp <= 0x9FFF:
                    codes.add(cp)
    sorted_codes = sorted(codes)
    print("// Auto-generated. Do not edit.")
    print("// Source: Tools/sanjiao-builder/scripts/generate-big5-level1.py")
    print(f"// Entries: {len(sorted_codes)} (Big5-HKSCS superset of classic Big5 level-1 5401)")
    print("enum Big5Level1Table {")
    print("    static let values: [UInt32] = [")
    for i in range(0, len(sorted_codes), 8):
        row = sorted_codes[i : i + 8]
        print("        " + ", ".join(f"0x{c:04X}" for c in row) + ",")
    print("    ]")
    print("}")


if __name__ == "__main__":
    main()
