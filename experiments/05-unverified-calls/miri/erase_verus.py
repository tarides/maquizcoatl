"""erase_verus.py: turns the Verus prototype's sources into plain Rust
for Miri (experiment #5, run B), by removing what Verus's own erasure
removes: the verus! wrapper, vstd's prelude, #[verifier::...]
attributes, spec functions, requires/ensures clauses, ghost lets and
asserts, and the names of return values. Ghost<T> becomes a plain
wrapper. The executable statements are kept as they are.

Usage: python3 -I erase_verus.py SRC_DIR OUT_DIR   (lib.rs, shim.rs, ffi.rs)
"""
import re
import sys
from pathlib import Path


def drop_block(lines, i):
    """Index after the brace-balanced block starting at line i."""
    depth = 0
    started = False
    while i < len(lines):
        depth += lines[i].count("{") - lines[i].count("}")
        started = started or "{" in lines[i]
        i += 1
        if started and depth == 0:
            return i
    raise SystemExit("unbalanced block")


def erase(text):
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        l = lines[i]
        s = l.strip()
        if s in ("use vstd::prelude::*;", "verus! {", "} // verus!"):
            i += 1
            continue
        if s.startswith("#[verifier::"):
            i += 1
            continue
        if re.match(r"pub (open |closed )?spec fn ", s):
            i = drop_block(lines, i)
            continue
        if s in ("requires", "ensures"):
            # The clause runs until the body's opening brace, alone on
            # its line at column 0 (rustfmt layout of the sources).
            while lines[i] != "{":
                i += 1
            continue
        if s.startswith("let ghost ") or s.startswith("assert("):
            i += 1
            continue
        out.append(l)
        i += 1
    text = "\n".join(out)
    # Named return values: "-> (r: T)" and the multi-line
    # "-> (res: (\n    i32,\n    Ghost<...>,\n))".
    text = re.sub(r"-> \(\w+: (\((?:[^()]|\([^()]*\)|<[^<>]*>)*\))\)",
                  lambda m: "-> " + re.sub(r"\s+", " ", m.group(1)), text)
    text = re.sub(r"-> \(\w+: ([^()]+)\)", r"-> \1", text)
    return text


def main():
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    for name in ("lib.rs", "shim.rs", "ffi.rs"):
        text = erase((src / name).read_text())
        if name == "lib.rs":
            text += ("\n/// Ghost<T> without Verus: a plain wrapper.\n"
                     "pub struct Ghost<T>(pub T);\n")
        (dst / name).write_text(text)


main()
