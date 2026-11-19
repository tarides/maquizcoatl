"""Directed depth probes for decision 3 (issue #9).

For each nesting shape, find by bisection the largest nesting k that
read-deep accepts without a depth error, then replay that input (and
k-1) with read-deep (ASan+UBSan) and read-deep-plain (no sanitizer)
under the current `ulimit -s`. Input format: fuzzer-deep (8 control
bytes: encoding, 4 option bytes, 2-byte pattern size, backward flag).
Usage: python3 -I deep-probe.py <harness-dir> <out-dir>
Prints one TSV line per (shape, k, binary).
"""
import os, subprocess, sys

H, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

SHAPES = {
    "group":      lambda k: b"(" * k + b"a" + b")" * k,
    "noncap":     lambda k: b"(?:" * k + b"a" + b")" * k,
    "cclass":     lambda k: b"[" * k + b"a" + b"]" * k,
    "lookbehind": lambda k: b"(?<=" * k + b"a" + b")" * k,
    "lookahead":  lambda k: b"(?=" * k + b"a" + b")" * k,
    "quant":      lambda k: b"(?:" * k + b"a" + b")*" * k,
    "alt":        lambda k: b"(?:a|" * k + b"b" + b")" * k,
    "absent":     lambda k: b"(?~" * k + b"a" + b")" * k,
    "option":     lambda k: b"(?i:" * k + b"a" + b")" * k,
    "atomic":     lambda k: b"(?>" * k + b"a" + b")" * k,
}

def make(p, subject=b"a" * 64):
    n = len(p)
    assert n < 65536
    ctrl = bytes([0, 0, 0, 0, 0xC0, n & 0xFF, n >> 8, 0])
    return ctrl + p + subject

def run(binary, data, timeout=300):
    try:
        r = subprocess.run([os.path.join(H, binary)], input=data,
                           capture_output=True, timeout=timeout)
        out = (r.stdout + r.stderr).decode("latin-1")
        return r.returncode, out
    except subprocess.TimeoutExpired:
        return "timeout", ""

def status(code, out):
    if code == "timeout":
        return "timeout"
    if "stack-overflow" in out:
        return "asan-stack-overflow"
    if "ERROR: AddressSanitizer" in out or "runtime error" in out:
        return "sanitizer-report"
    if code == -11 or code == 139:
        return "SIGSEGV"
    if code not in (0,):
        return "exit-%s" % code
    for line in out.splitlines():
        if line.startswith("ERROR: "):
            return "onig-error: " + line[7:]
    return "ok"

def depth_error(st):
    return "depth limit" in st

for name, f in SHAPES.items():
    lo, hi = 1, 8192
    while len(f(hi)) >= 65000:
        hi //= 2
    # largest k with no depth error under read-deep-plain
    if not depth_error(status(*run("read-deep-plain", make(f(hi))))):
        lo = hi
    else:
        while lo + 1 < hi:
            mid = (lo + hi) // 2
            st = status(*run("read-deep-plain", make(f(mid))))
            if depth_error(st):
                hi = mid
            else:
                lo = mid
    for k in sorted({lo, lo + 1}):
        data = make(f(k))
        fn = os.path.join(OUT, "%s-%d.bin" % (name, k))
        with open(fn, "wb") as fh:
            fh.write(data)
        for b in ("read-deep-plain", "read-deep"):
            code, out = run(b, data)
            st = status(code, out)
            if st != "ok" and st != "onig-error" and b == "read-deep":
                with open(fn + ".%s.txt" % b, "w") as fh:
                    fh.write(out[-20000:])
            print("%s\t%d\t%d\t%s\t%s" % (name, k, len(f(k)), b, st), flush=True)
