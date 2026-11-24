"""Directed depth probes for decision 3 (issue #9).

For each nesting shape, find by bisection the largest nesting k that
read-deep-plain accepts without a parse-depth error, then replay k and
k+1 with read-deep-plain (no sanitizer), read-deep (ASan+UBSan) and
read-deep-ns (read-deep without the harness's shift-base check, see
build.sh) under the current `ulimit -s`. Then, for each input at k,
run read-deep-plain under `ulimit -s` 1024, 512 and 256 KiB, and bisect
the smallest `ulimit -s` (KiB) between 1024 and 8192 at which it does
not crash with SIGSEGV, to 16 KiB resolution.
Input format: fuzzer-deep (8 control bytes: encoding, 4 option bytes,
2-byte pattern size, backward flag).
Usage: python3 -I deep-probe.py <harness-dir> <out-dir>
Prints one TSV line per (shape, k, binary) on stdout, and writes to
<out-dir>, besides the inputs and the read-deep* failure reports:
  read-deep-ns.tsv      file, exit code, first "ERROR" line
  plain-small-stack.tsv ulimit -s (KiB), file, exit code (139 = SIGSEGV)
  plain-min-stack.tsv   file, largest crashing and smallest passing
                        ulimit -s (KiB) found by the bisection
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

def run(binary, data, timeout=300, stack_kib=None):
    cmd = [os.path.join(H, binary)]
    if stack_kib is not None:
        cmd = ["sh", "-c", 'ulimit -s %d && exec "$0"' % stack_kib] + cmd
    try:
        r = subprocess.run(cmd, input=data,
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

NS = []       # read-deep-ns.tsv lines
DEEPEST = []  # input files at the largest accepted k, one per shape

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
        for b in ("read-deep-plain", "read-deep", "read-deep-ns"):
            code, out = run(b, data)
            st = status(code, out)
            if st != "ok" and not st.startswith("onig-error") and b != "read-deep-plain":
                with open(fn + ".%s.txt" % b, "w") as fh:
                    fh.write(out[-20000:])
            print("%s\t%d\t%d\t%s\t%s" % (name, k, len(f(k)), b, st), flush=True)
            if b == "read-deep-ns":
                err = next((l.split("==", 2)[-1] if l.startswith("==") else l
                            for l in out.splitlines() if "ERROR:" in l), "")
                err = err.split(" on address")[0]
                ex = "timeout" if code == "timeout" else (
                    code if code >= 0 else 128 - code)
                NS.append("%s\t%s\t%s" % (os.path.basename(fn), ex, err))
    DEEPEST.append(os.path.join(OUT, "%s-%d.bin" % (name, lo)))

def exitcode(fn, kib):
    """Exit status of read-deep-plain on fn under `ulimit -s kib`."""
    with open(fn, "rb") as fh:
        code, _ = run("read-deep-plain", fh.read(), stack_kib=kib)
    return 128 - code if isinstance(code, int) and code < 0 else code

def crashes(fn, kib):
    return exitcode(fn, kib) == 139

with open(os.path.join(OUT, "read-deep-ns.tsv"), "w") as fh:
    fh.write("".join(l + "\n" for l in NS))
with open(os.path.join(OUT, "plain-small-stack.tsv"), "w") as fh:
    for kib in (1024, 512, 256):
        for fn in DEEPEST:
            fh.write("%d\t%s\t%s\n" % (kib, os.path.basename(fn), exitcode(fn, kib)))
with open(os.path.join(OUT, "plain-min-stack.tsv"), "w") as fh:
    for fn in DEEPEST:
        lo, hi = 1024, 8192  # bisection invariant: lo crashes, hi passes
        if not crashes(fn, lo) or crashes(fn, hi):
            fh.write("%s\tNA\tNA\n" % os.path.basename(fn))
            continue
        while hi - lo > 16:
            mid = (lo + hi) // 2
            if crashes(fn, mid):
                lo = mid
            else:
                hi = mid
        fh.write("%s\t%d\t%d\n" % (os.path.basename(fn), lo, hi))
