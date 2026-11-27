#!/usr/bin/env python3
"""Issue #22: restrict experiment #12's work files to experiment #9's
fragment (decision 2, plan requirement 8).

usage: python3 -I prep22.py SELECT_PY WORK12 OUT

WORK12 holds experiment #12's work files, written by its prep.py,
main.exe classify and pick_large.py: <fam>.all.work, <fam>.work (its
classified subset), large.list, large.work.  A call is admitted when

  - its pattern entry has syntax 0, 1 or 2 (ONIGURUMA, RUBY, PERL_NG;
    prep.py writes 8 for a non-UTF-8 encoding, 9 for another syntax);
  - its compile options are within MULTILINE, SINGLELINE,
    NEGATE_SINGLELINE, CAPTURE_GROUP and the five *_IS_ASCII options,
    and its search options within NOTBOL | NOTEOL;
  - select.py's recognise (imported unchanged from SELECT_PY) accepts
    the pattern bytes;
  - it is a forward call (range >= start, or a match call).

The first rule a call fails is its rejection reason.  Writes to OUT:
<fam>.frag.work (same format), <fam>.ast.tsv (pattern id, recognise's
s-expression), coverage.tsv and coverage.md, and the restricted
large.list and large.work (rank and pattern id kept).  Exits non-zero
if an admitted call is outside experiment #12's subset (<fam>.work).
"""
import importlib.util, os, sys
from collections import Counter

FAMILIES = ["jq", "php", "vscode", "longphp"]
OPTIONS = 4 | 8 | 64 | 256 | 32768 | 65536 | 131072 | 262144 | 524288
SEARCH_OPTIONS = 512 | 1024


def load_select(path):
    spec = importlib.util.spec_from_file_location("select22", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def read_work(path):
    P, S, C = {}, {}, []
    for l in open(path):
        f = l.split()
        if f[0] == "P":
            P[int(f[1])] = f
        elif f[0] == "S":
            S[int(f[1])] = l
        elif f[0] == "C":
            C.append(f)
    return P, S, C


def pattern_reason(sel, f):
    """Reason a pattern entry (P line fields) is outside, or None, and its AST."""
    syn, opt = int(f[2]), int(f[3])
    if syn == 8:
        return "encoding not UTF-8", None
    if syn not in (0, 1, 2):
        return "syntax not ONIGURUMA, RUBY or PERL_NG", None
    if opt & ~OPTIONS:
        return "compile options", None
    pat = bytes.fromhex(f[6]) if len(f) > 6 else b""
    try:
        ast, _ = sel.recognise(pat)
    except sel.Out as e:
        return f"recognise: {e}", None
    return None, sel.sexp(ast)


def main():
    sel = load_select(sys.argv[1])
    w12, out = sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    cov = []
    problems = []
    for fam in FAMILIES:
        P, S, C = read_work(os.path.join(w12, f"{fam}.all.work"))
        _, _, C12 = read_work(os.path.join(w12, f"{fam}.work"))
        in12 = {c[1] for c in C12}
        pr = {pid: pattern_reason(sel, f) for pid, f in P.items()}
        kept = []
        reasons = Counter()
        wreasons = Counter()
        for c in C:
            cid, pid, sid, kind, start, rng, sopt, weight = (int(x) for x in c[1:])
            r, _ = pr[pid]
            if r is None and sopt & ~SEARCH_OPTIONS:
                r = "search options"
            if r is None and kind == 0 and rng < start:
                r = "backward call"
            if r is None:
                kept.append(c)
                if c[1] not in in12:
                    problems.append(f"{fam} case {cid}: admitted, outside experiment #12's subset")
            else:
                reasons[r] += 1
                wreasons[r] += weight
        pids = sorted({int(c[2]) for c in kept})
        sids = sorted({int(c[3]) for c in kept})
        with open(os.path.join(out, f"{fam}.frag.work"), "w") as w:
            for pid in pids:
                w.write(" ".join(P[pid]) + "\n")
            for sid in sids:
                w.write(S[sid])
            for c in kept:
                w.write(" ".join(c) + "\n")
        with open(os.path.join(out, f"{fam}.ast.tsv"), "w") as w:
            for pid in pids:
                w.write(f"{pid}\t{pr[pid][1]}\n")
        tw = sum(int(c[8]) for c in C)
        kw = sum(int(c[8]) for c in kept)
        cov.append((fam, len(kept), len(C), kw, tw, len(pids), len(P), reasons, wreasons))
    # large shape: experiment #12's ranked list restricted to the fragment
    P, _, _ = read_work(os.path.join(w12, "large.work"))
    rows = [l.split() for l in open(os.path.join(w12, "large.list"))]
    keep_rows, lreasons = [rows[0]], Counter()
    for r in rows[1:]:
        reason, _ = pattern_reason(sel, P[int(r[2])])
        if reason is None:
            keep_rows.append(r)
        else:
            lreasons[(r[0], reason, bytes.fromhex(r[5]).decode("ascii", "replace"))] += 1
    with open(os.path.join(out, "large.list"), "w") as w:
        for r in keep_rows:
            w.write(" ".join(r) + "\n")
    lp = sorted({int(r[2]) for r in keep_rows[1:]})
    with open(os.path.join(out, "large.work"), "w") as w:
        for pid in lp:
            w.write(" ".join(P[pid]) + "\n")
    with open(os.path.join(out, "large.ast.tsv"), "w") as w:
        for pid in lp:
            w.write(f"{pid}\t{pattern_reason(sel, P[pid])[1]}\n")
    # coverage
    with open(os.path.join(out, "coverage.tsv"), "w") as w:
        w.write("family\tcalls_admitted\tcalls_total\tweighted_admitted\tweighted_total\tpatterns_admitted\tpatterns_total\n")
        for fam, k, t, kw, tw, kp, tp, _, _ in cov:
            w.write(f"{fam}\t{k}\t{t}\t{kw}\t{tw}\t{kp}\t{tp}\n")
    lines = ["| Family | Calls admitted | Weighted (VS Code frequency profile) | Pattern entries with an admitted call |",
             "|---|---:|---:|---:|"]
    for fam, k, t, kw, tw, kp, tp, _, _ in cov:
        lines.append(f"| {fam} | {k:,} / {t:,} ({100 * k / t:.1f}%) | "
                     + (f"{kw:,} / {tw:,} ({100 * kw / tw:.1f}%)" if fam == "vscode" else "")
                     + f" | {kp:,} / {tp:,} |")
    lines += ["", "Rejection reasons (first rule failed; calls, and weighted calls for VS Code):", ""]
    for fam, _, _, _, _, _, _, rs, wrs in cov:
        lines.append(f"- {fam}: " + "; ".join(
            f"`{r}` {n:,}" + (f" (weighted {wrs[r]:,})" if fam == "vscode" else "")
            for r, n in rs.most_common()))
    lines += ["", f"Large shape: {sum(1 for r in keep_rows[1:] if r[0] == 'log')} log patterns and "
              f"{sum(1 for r in keep_rows[1:] if r[0] == 'src')} source patterns kept of experiment #12's "
              f"{sum(1 for r in rows[1:] if r[0] == 'log')} and {sum(1 for r in rows[1:] if r[0] == 'src')}; left out: "
              + "; ".join(f"{s} `{p}` ({r})" for (s, r, p), n in sorted(lreasons.items()))]
    if problems:
        lines += ["", "Problems:", ""] + [f"- {p}" for p in problems]
    open(os.path.join(out, "coverage.md"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
