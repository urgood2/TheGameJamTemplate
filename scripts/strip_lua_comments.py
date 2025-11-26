#!/usr/bin/env python3
"""
Strip Lua comments (line and block) from a source file while preserving strings.
Used in release/web asset packing to reduce payload size.
"""

import sys
from pathlib import Path


def match_long_bracket(s: str, idx: int):
    """
    If s[idx:] starts with [=*[ return the number of '=' characters, else None.
    """
    if idx >= len(s) or s[idx] != "[":
        return None
    j = idx + 1
    while j < len(s) and s[j] == "=":
        j += 1
    if j < len(s) and s[j] == "[":
        return j - idx - 1
    return None


def strip_comments(src: str) -> str:
    out = []
    i = 0
    n = len(src)
    state = "normal"  # normal | string | long_string | line_comment | long_comment
    quote = ""
    long_eqs = 0

    while i < n:
        ch = src[i]

        if state == "normal":
            if ch == "-" and i + 1 < n and src[i + 1] == "-":
                i += 2
                lb = match_long_bracket(src, i)
                if lb is not None:
                    state = "long_comment"
                    long_eqs = lb
                    i += lb + 2  # skip [[ or [=[ etc
                else:
                    state = "line_comment"
                continue

            if ch in ("'", '"'):
                state = "string"
                quote = ch
                out.append(ch)
                i += 1
                continue

            lb = match_long_bracket(src, i) if ch == "[" else None
            if lb is not None:
                state = "long_string"
                long_eqs = lb
                out.append("[" + ("=" * lb) + "[")
                i += lb + 2
                continue

            out.append(ch)
            i += 1
            continue

        if state == "string":
            out.append(ch)
            i += 1
            if ch == "\\" and i < n:
                out.append(src[i])
                i += 1
            elif ch == quote:
                state = "normal"
            continue

        if state == "long_string":
            out.append(ch)
            if ch == "]" and src.startswith("=" * long_eqs + "]", i + 1):
                out.append("=" * long_eqs)
                out.append("]")
                i += long_eqs + 2
                state = "normal"
            else:
                i += 1
            continue

        if state == "line_comment":
            if ch == "\n":
                out.append("\n")
                state = "normal"
            i += 1
            continue

        if state == "long_comment":
            if ch == "]" and src.startswith("=" * long_eqs + "]", i + 1):
                i += long_eqs + 2
                state = "normal"
                continue
            if ch == "\n":
                out.append("\n")
            i += 1
            continue

    return "".join(out)


def main():
    if len(sys.argv) != 3:
        print("usage: strip_lua_comments.py <input> <output>", file=sys.stderr)
        return 1

    src_path = Path(sys.argv[1])
    dst_path = Path(sys.argv[2])
    data = src_path.read_text(encoding="utf-8")
    stripped = strip_comments(data)
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    dst_path.write_text(stripped, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
