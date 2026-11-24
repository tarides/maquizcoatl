#!/usr/bin/env python3
"""Experiment #6 milestone 2: generate the prover case and table modules
for the S2 cases.

Input: the in-S2 file written by `g2 classify` (idx id kind pat sub a b
c syntax options ncap ast), the C oracle's verdicts (id TAB verdict) and
the tables (tables.txt, from g/tables/gen_tables.py).  Cases whose
pattern stack G's parser rejects (kind e, ast "!") stay with stack G and
are not emitted, as in milestone 1.  The expected value of each case is
the C library's verdict, encoded as in the semantics.

Table modules: the case-fold map in full and, for the properties, either
only the ctypes the emitted cases use plus the word ctype (12, for \\b):
"restricted", the main runs; or every ctype of upstream's CodeRanges:
"full", the spot check of decision 2 on issue #28.  Both are balanced
decision trees (no list constant), with the same interface.

usage: python3 -I gen2.py IN-S2.tsv ORACLE.txt TABLES.txt OUTDIR [HEAVY]
writes OUTDIR/{restricted,full}/{tables.mlw,Tables.fst,Tables.v,Tables.lean,
Tables.thy,tables2.rs}, OUTDIR/{cases.mlw,Cases.fst,Cases.v,Cases.lean,
Cases.thy,cases2.rs}, OUTDIR/ids.txt, OUTDIR/used-ctypes.txt (Rocq and
Lean modules: run 2; Isabelle/HOL and Verus modules: run 3); with HEAVY,
also OUTDIR/heavy/{cases.mlw,...,cases2.rs,ids.txt}: the property-heavy cases
(those whose AST holds a property or ctype other than a POSIX/ASCII
ctype set by '.', i.e. any CP node).
"""
import sys, os

# ---- s-expressions of g2.ml ----------------------------------------


def tokens(s):
    return s.replace("(", " ( ").replace(")", " ) ").split()


def parse_cs(toks, i):
    t = toks[i]
    if t == "(":
        op = toks[i + 1]; i += 2
        args = []
        while toks[i] != ")":
            a, i = parse_cs(toks, i); args.append(a)
        i += 1
        if op == "!": return ("not", args[0]), i
        if op == "+": return ("or", args), i
        if op == "&": return ("and", args[0], args[1]), i
        raise ValueError(op)
    if t[0] == "r":
        a, b = t[1:].split("-"); return ("r", int(a, 16), int(b, 16)), i + 1
    if t[0] == "p":
        return ("p", int(t[1:])), i + 1
    raise ValueError(t)


def hexlist(t):
    return [int(x, 16) for x in t.split(",")] if t else []


def parse_node(toks, i):
    t = toks[i]
    if t == "(":
        op = toks[i + 1]; i += 2
        if op == "c":
            cs, i = parse_cs(toks, i); return ("cls", cs), i + 1
        if op == "ci":
            cs, i = parse_cs(toks, i); ms = []
            while toks[i] != ")":
                ms.append(hexlist(toks[i])); i += 1
            return ("clsi", cs, ms), i + 1
        if op in (".", "|"):
            a, i = parse_node(toks, i); b, i = parse_node(toks, i)
            return ("cat" if op == "." else "alt", a, b), i + 1
        if op in ("*", "*?"):
            mn, mx = int(toks[i]), int(toks[i + 1])
            a, i = parse_node(toks, i + 2)
            return ("rep", mn, mx, op == "*", a), i + 1
        if op in (">", "?=", "?!"):
            a, i = parse_node(toks, i)
            if op == ">": return ("atomic", a), i + 1
            return ("ahead", op == "?!", a), i + 1
        if op in ("?<=", "?<!"):
            alts = []
            while toks[i] != ")":
                a, i = parse_node(toks, i); alts.append(a)
            return ("behind", op == "?<!", alts), i + 1
        if op == "g":
            k = int(toks[i]); a, i = parse_node(toks, i + 1)
            return ("group", k, a), i + 1
        if op in ("k", "ki"):
            gs = [int(x) for x in toks[i].split(",")]
            return ("bref", gs, op == "ki"), i + 2
        raise ValueError(op)
    if t == "E": return ("eps",), i + 1
    if t[0] == "L":
        h = t[1:]; return ("lit", [int(h[j:j + 2], 16) for j in range(0, len(h), 2)]), i + 1
    if t[0] == "I": return ("liti", hexlist(t[1:])), i + 1
    if t[0] == "^": return ("anc", t[1:]), i + 1
    raise ValueError(t)


def parse(s):
    n, i = parse_node(tokens(s), 0)
    return n


def walk(n, f):
    f(n)
    for x in n[1:]:
        if isinstance(x, tuple): walk(x, f)
        if isinstance(x, list):
            for y in x:
                if isinstance(y, tuple): walk(y, f)


def cs_props(cs, acc):
    if cs[0] == "p": acc.add(cs[1])
    elif cs[0] == "not": cs_props(cs[1], acc)
    elif cs[0] == "or":
        for c in cs[1]: cs_props(c, acc)
    elif cs[0] == "and": cs_props(cs[1], acc); cs_props(cs[2], acc)


def props_of(ast):
    acc = set()
    def f(n):
        if n[0] in ("cls", "clsi"): cs_props(n[1], acc)
    walk(ast, f)
    return acc


def refs_of(ast):
    acc = set()
    def f(n):
        if n[0] == "bref": acc.update(n[1])
    walk(ast, f)
    return sorted(acc)


def expected(verdict, ncap):
    w = verdict.split()
    if w[0] == "MISMATCH": return [0]
    if w[0] == "LIMIT": return [2]
    if w[0] == "ERR": return [3]      # C rejects, stack G compiles (DEV-004)
    assert w[0] == "MATCH", verdict
    v = [int(x) for x in w[1:]]
    assert len(v) == 2 * (ncap + 1), (verdict, ncap)
    out = [1, v[0], v[1]]
    for k in range(1, ncap + 1):
        s, e = v[2 * k], v[2 * k + 1]
        out += [0] if s < 0 else [1, s, e]
    return out

# ---- Why3 printers --------------------------------------------------

ANC = {"bol": "BolA", "eol": "EolA", "A": "BufBeg", "z": "BufEnd", "Z": "SemiEnd",
       "G": "SearchStart", "b": "WordB", "B": "NotWordB"}


def w_list(xs, nil="BNil", cons="BCons"):
    out = nil
    for x in reversed(list(xs)):
        out = f"({cons} {x} {out})"
    return out


def w_int(x):
    return f"({x})" if x < 0 else str(x)


def w_cs(cs):
    if cs[0] == "r": return f"(CR {cs[1]} {cs[2]})"
    if cs[0] == "p": return f"(CP {cs[1]})"
    if cs[0] == "not": return f"(CNot {w_cs(cs[1])})"
    if cs[0] == "or": return f"(COr {w_list([w_cs(c) for c in cs[1]], 'SNil', 'SCons')})"
    if cs[0] == "and": return f"(CAnd {w_cs(cs[1])} {w_cs(cs[2])})"


def w_node(n):
    op = n[0]
    if op == "eps": return "Eps"
    if op == "lit": return f"(Lit {w_list(n[1])})"
    if op == "liti": return f"(LitI {w_list(n[1])})"
    if op == "cls": return f"(Cls {w_cs(n[1])})"
    if op == "clsi":
        return f"(ClsI {w_cs(n[1])} {w_list([w_list(m) for m in n[2]], 'FsNil', 'FsCons')})"
    if op == "cat": return f"(Cat {w_node(n[1])} {w_node(n[2])})"
    if op == "alt": return f"(Alt {w_node(n[1])} {w_node(n[2])})"
    if op == "rep": return f"(Rep {n[1]} {w_int(n[2])} {'true' if n[3] else 'false'} {w_node(n[4])})"
    if op == "atomic": return f"(Atomic {w_node(n[1])})"
    if op == "ahead": return f"(Ahead {'true' if n[1] else 'false'} {w_node(n[2])})"
    if op == "behind":
        return f"(Behind {'true' if n[1] else 'false'} {w_list([w_node(a) for a in n[2]], 'NNil', 'NCons')})"
    if op == "group": return f"(Group {n[1]} {w_node(n[2])})"
    if op == "bref": return f"(Bref {w_list(n[1])} {'true' if n[2] else 'false'})"
    if op == "anc": return f"(Anc {ANC[n[1]]})"
    raise ValueError(op)

# ---- F* printers ----------------------------------------------------

FANC = ANC


def f_list(xs):
    return "[" + "; ".join(xs) + "]"


def f_cs(cs):
    if cs[0] == "r": return f"(CR {cs[1]} {cs[2]})"
    if cs[0] == "p": return f"(CP {cs[1]})"
    if cs[0] == "not": return f"(CNot {f_cs(cs[1])})"
    if cs[0] == "or": return f"(COr {f_list([f_cs(c) for c in cs[1]])})"
    if cs[0] == "and": return f"(CAnd {f_cs(cs[1])} {f_cs(cs[2])})"


def f_ints(xs):
    return f_list([w_int(x) for x in xs])


def f_node(n):
    op = n[0]
    if op == "eps": return "Eps"
    if op == "lit": return f"(Lit {f_ints(n[1])})"
    if op == "liti": return f"(LitI {f_ints(n[1])})"
    if op == "cls": return f"(Cls {f_cs(n[1])})"
    if op == "clsi": return f"(ClsI {f_cs(n[1])} {f_list([f_ints(m) for m in n[2]])})"
    if op == "cat": return f"(Cat {f_node(n[1])} {f_node(n[2])})"
    if op == "alt": return f"(Alt {f_node(n[1])} {f_node(n[2])})"
    if op == "rep": return f"(Rep {n[1]} {w_int(n[2])} {'true' if n[3] else 'false'} {f_node(n[4])})"
    if op == "atomic": return f"(Atomic {f_node(n[1])})"
    if op == "ahead": return f"(Ahead {'true' if n[1] else 'false'} {f_node(n[2])})"
    if op == "behind":
        return f"(Behind {'true' if n[1] else 'false'} {f_list([f_node(a) for a in n[2]])})"
    if op == "group": return f"(Group {n[1]} {f_node(n[2])})"
    if op == "bref": return f"(Bref {f_ints(n[1])} {'true' if n[2] else 'false'})"
    if op == "anc": return f"(Anc {FANC[n[1]]})"
    raise ValueError(op)

# ---- Rocq printers (run 2) --------------------------------------------

RANC = ANC


def r_nlist(xs):
    """a list of N"""
    return "[" + "; ".join(str(x) for x in xs) + "]%N"


def r_list(xs):
    return "[" + "; ".join(xs) + "]"


def r_cs(cs):
    if cs[0] == "r": return f"(CR {cs[1]} {cs[2]})"
    if cs[0] == "p": return f"(CP {cs[1]})"
    if cs[0] == "not": return f"(CNot {r_cs(cs[1])})"
    if cs[0] == "or": return f"(COr {r_list([r_cs(c) for c in cs[1]])})"
    if cs[0] == "and": return f"(CAnd {r_cs(cs[1])} {r_cs(cs[2])})"


def r_node(n):
    op = n[0]
    if op == "eps": return "Eps"
    if op == "lit": return f"(Lit {r_nlist(n[1])})"
    if op == "liti": return f"(LitI {r_nlist(n[1])})"
    if op == "cls": return f"(Cls {r_cs(n[1])})"
    if op == "clsi": return f"(ClsI {r_cs(n[1])} {r_list([r_nlist(m) for m in n[2]])})"
    if op == "cat": return f"(Cat {r_node(n[1])} {r_node(n[2])})"
    if op == "alt": return f"(Alt {r_node(n[1])} {r_node(n[2])})"
    if op == "rep":
        mx = "None" if n[2] < 0 else f"(Some {n[2]}%N)"
        return f"(Rep {n[1]} {mx} {'true' if n[3] else 'false'} {r_node(n[4])})"
    if op == "atomic": return f"(Atomic {r_node(n[1])})"
    if op == "ahead": return f"(Ahead {'true' if n[1] else 'false'} {r_node(n[2])})"
    if op == "behind":
        return f"(Behind {'true' if n[1] else 'false'} {r_list([r_node(a) for a in n[2]])})"
    if op == "group": return f"(Group {n[1]} {r_node(n[2])})"
    if op == "bref": return f"(Bref {r_list([str(x) for x in n[1]])} {'true' if n[2] else 'false'})"
    if op == "anc": return f"(Anc {RANC[n[1]]})"
    raise ValueError(op)

# ---- Lean printers (run 2) --------------------------------------------

LANC = {"bol": "bol", "eol": "eol", "A": "bufBeg", "z": "bufEnd", "Z": "semiEnd",
        "G": "searchStart", "b": "wordB", "B": "notWordB"}


def l_list(xs):
    return "[" + ", ".join(xs) + "]"


def l_nlist(xs):
    return l_list([str(x) for x in xs])


def l_cs(cs):
    if cs[0] == "r": return f"(CSet.cr {cs[1]} {cs[2]})"
    if cs[0] == "p": return f"(CSet.cp {cs[1]})"
    if cs[0] == "not": return f"(CSet.cnot {l_cs(cs[1])})"
    if cs[0] == "or": return f"(CSet.cor {l_list([l_cs(c) for c in cs[1]])})"
    if cs[0] == "and": return f"(CSet.cand {l_cs(cs[1])} {l_cs(cs[2])})"


def l_node(n):
    op = n[0]
    if op == "eps": return "Node.eps"
    if op == "lit": return f"(Node.lit {l_nlist(n[1])})"
    if op == "liti": return f"(Node.litI {l_nlist(n[1])})"
    if op == "cls": return f"(Node.cls {l_cs(n[1])})"
    if op == "clsi": return f"(Node.clsI {l_cs(n[1])} {l_list([l_nlist(m) for m in n[2]])})"
    if op == "cat": return f"(Node.cat {l_node(n[1])} {l_node(n[2])})"
    if op == "alt": return f"(Node.alt {l_node(n[1])} {l_node(n[2])})"
    if op == "rep":
        mx = "none" if n[2] < 0 else f"(some {n[2]})"
        return f"(Node.rep {n[1]} {mx} {'true' if n[3] else 'false'} {l_node(n[4])})"
    if op == "atomic": return f"(Node.atomic {l_node(n[1])})"
    if op == "ahead": return f"(Node.ahead {'true' if n[1] else 'false'} {l_node(n[2])})"
    if op == "behind":
        return f"(Node.behind {'true' if n[1] else 'false'} {l_list([l_node(a) for a in n[2]])})"
    if op == "group": return f"(Node.group {n[1]} {l_node(n[2])})"
    if op == "bref": return f"(Node.bref {l_nlist(n[1])} {'true' if n[2] else 'false'})"
    if op == "anc": return f"(Node.anc Anchor.{LANC[n[1]]})"
    raise ValueError(op)

# ---- Isabelle/HOL printers (run 3) ------------------------------------

IANC = {"bol": "BolA", "eol": "EolA", "A": "BufBeg", "z": "BufEnd", "Z": "SemiEnd",
        "G": "SearchStart", "b": "WordB", "B": "NotWordB"}


def i_list(xs):
    return "[" + ", ".join(xs) + "]"


def i_nlist(xs):
    return i_list([str(x) for x in xs])


def i_bool(b):
    return "True" if b else "False"


def i_cs(cs):
    if cs[0] == "r": return f"(CR {cs[1]} {cs[2]})"
    if cs[0] == "p": return f"(CP {cs[1]})"
    if cs[0] == "not": return f"(CNot {i_cs(cs[1])})"
    if cs[0] == "or": return f"(COr {i_list([i_cs(c) for c in cs[1]])})"
    if cs[0] == "and": return f"(CAnd {i_cs(cs[1])} {i_cs(cs[2])})"


def i_node(n):
    op = n[0]
    if op == "eps": return "Eps"
    if op == "lit": return f"(Lit {i_nlist(n[1])})"
    if op == "liti": return f"(LitI {i_nlist(n[1])})"
    if op == "cls": return f"(Cls {i_cs(n[1])})"
    if op == "clsi": return f"(ClsI {i_cs(n[1])} {i_list([i_nlist(m) for m in n[2]])})"
    if op == "cat": return f"(Cat {i_node(n[1])} {i_node(n[2])})"
    if op == "alt": return f"(Alt {i_node(n[1])} {i_node(n[2])})"
    if op == "rep":
        mx = "None" if n[2] < 0 else f"(Some {n[2]})"
        return f"(Rep {n[1]} {mx} {i_bool(n[3])} {i_node(n[4])})"
    if op == "atomic": return f"(Atomic {i_node(n[1])})"
    if op == "ahead": return f"(Ahead {i_bool(n[1])} {i_node(n[2])})"
    if op == "behind": return f"(Behind {i_bool(n[1])} {i_list([i_node(a) for a in n[2]])})"
    if op == "group": return f"(Group {n[1]} {i_node(n[2])})"
    if op == "bref": return f"(Bref {i_nlist(n[1])} {i_bool(n[2])})"
    if op == "anc": return f"(Anc {IANC[n[1]]})"
    raise ValueError(op)

# ---- Verus (Rust) printers (run 3) --------------------------------------

RSANC = {"bol": 0, "eol": 1, "A": 2, "z": 3, "Z": 4, "G": 5, "b": 6, "B": 7}


def rust_arena2(ast):
    """the pattern as spec2.rs's arena: nodes and side pools, children
    by index (children before parents)"""
    a = {k: [] for k in ("nodes", "bytes", "cps", "seqs", "kids", "gidx", "csets", "cidx")}

    def pool(k, xs):
        st = len(a[k]); a[k].extend(xs); return st, len(xs)

    def cset(cs):
        if cs[0] == "r": d = f"CSet::Cr({cs[1]}, {cs[2]})"
        elif cs[0] == "p": d = f"CSet::Cp({cs[1]})"
        elif cs[0] == "not": d = f"CSet::CNot({cset(cs[1])})"
        elif cs[0] == "or":
            ch = [cset(c) for c in cs[1]]
            st, ln = pool("cidx", [str(x) for x in ch]); d = f"CSet::COr({st}, {ln})"
        elif cs[0] == "and":
            x, y = cset(cs[1]), cset(cs[2]); d = f"CSet::CAnd({x}, {y})"
        a["csets"].append(d)
        return len(a["csets"]) - 1

    def node(n):
        op = n[0]
        if op == "eps": d = "Node::Eps"
        elif op == "lit":
            st, ln = pool("bytes", [str(x) for x in n[1]]); d = f"Node::Lit({st}, {ln})"
        elif op == "liti":
            st, ln = pool("cps", [str(x) for x in n[1]]); d = f"Node::LitI({st}, {ln})"
        elif op == "cls": d = f"Node::Cls({cset(n[1])})"
        elif op == "clsi":
            c = cset(n[1])
            ms = [pool("cps", [str(x) for x in m]) for m in n[2]]
            st, ln = pool("seqs", [f"({x}, {y})" for x, y in ms])
            d = f"Node::ClsI({c}, {st}, {ln})"
        elif op in ("cat", "alt"):
            x, y = node(n[1]), node(n[2])
            d = f"Node::{'Cat' if op == 'cat' else 'Alt'}({x}, {y})"
        elif op == "rep":
            mx = "None" if n[2] < 0 else f"Some({n[2]})"
            d = f"Node::Rep({n[1]}, {mx}, {'true' if n[3] else 'false'}, {node(n[4])})"
        elif op == "atomic": d = f"Node::Atomic({node(n[1])})"
        elif op == "ahead": d = f"Node::Ahead({'true' if n[1] else 'false'}, {node(n[2])})"
        elif op == "behind":
            ch = [node(x) for x in n[2]]
            st, ln = pool("kids", [str(x) for x in ch])
            d = f"Node::Behind({'true' if n[1] else 'false'}, {st}, {ln})"
        elif op == "group": d = f"Node::Group({n[1]}, {node(n[2])})"
        elif op == "bref":
            st, ln = pool("gidx", [str(x) for x in n[1]])
            d = f"Node::Bref({st}, {ln}, {'true' if n[2] else 'false'})"
        elif op == "anc": d = f"Node::Anc({RSANC[n[1]]})"
        else: raise ValueError(op)
        a["nodes"].append(d)
        return len(a["nodes"]) - 1

    root = node(ast)
    return a, root


# ---- tables ---------------------------------------------------------


def load_tables(f):
    folds, ranges = {}, {}
    for l in open(f):
        p = l.rstrip("\n").split("\t")
        if p[0] == "F":
            folds[int(p[1], 16)] = [int(x, 16) for x in p[2].split(",")]
        elif p[0] == "R":
            rs = []
            if p[2]:
                for r in p[2].split(","):
                    a, b = r.split("-"); rs.append((int(a, 16), int(b, 16)))
            ranges[int(p[1])] = rs
    return folds, ranges


def tree_fold(keys, folds, ind, lang):
    """balanced decision tree c -> fold list"""
    if not keys:
        return "BCons c BNil" if lang == "w" else "[c]"
    m = len(keys) // 2
    k = keys[m]
    v = w_list(folds[k]) if lang == "w" else f_ints(folds[k])
    l = tree_fold(keys[:m], folds, ind + 1, lang)
    r = tree_fold(keys[m + 1:], folds, ind + 1, lang)
    sp = "  " * ind
    return (f"(if c < {k} then\n{sp}  {l}\n{sp}else if c = {k} then {v}\n{sp}else\n{sp}  {r})")


def tree_ranges(rs, ind):
    if not rs:
        return "false"
    m = len(rs) // 2
    lo, hi = rs[m]
    sp = "  " * ind
    l = tree_ranges(rs[:m], ind + 1)
    r = tree_ranges(rs[m + 1:], ind + 1)
    return (f"(if c < {lo} then\n{sp}  {l}\n{sp}else if c <= {hi} then true\n{sp}else\n{sp}  {r})")


def tree_fold_rl(keys, folds, ind, lang):
    """balanced decision tree c -> fold list, Rocq ("r") or Lean ("l")"""
    if not keys:
        return "[c]"
    m = len(keys) // 2
    k = keys[m]
    v = r_nlist(folds[k]) if lang == "r" else l_nlist(folds[k])
    lt, eq = ("N.ltb c", "N.eqb c") if lang == "r" else ("c <", "c ==")
    l = tree_fold_rl(keys[:m], folds, ind + 1, lang)
    r = tree_fold_rl(keys[m + 1:], folds, ind + 1, lang)
    sp = "  " * ind
    return (f"(if {lt} {k} then\n{sp}  {l}\n{sp}else if {eq} {k} then {v}\n{sp}else\n{sp}  {r})")


def tree_ranges_rl(rs, ind, lang):
    if not rs:
        return "false"
    m = len(rs) // 2
    lo, hi = rs[m]
    sp = "  " * ind
    lt, le = ("N.ltb c", "N.leb c") if lang == "r" else ("c <", "c ≤")
    l = tree_ranges_rl(rs[:m], ind + 1, lang)
    r = tree_ranges_rl(rs[m + 1:], ind + 1, lang)
    return (f"(if {lt} {lo} then\n{sp}  {l}\n{sp}else if {le} {hi} then true\n{sp}else\n{sp}  {r})")


def disp_rl(ps, ind, lang):
    if not ps: return "false"
    m = len(ps) // 2
    sp = "  " * ind
    lt, eq = ("N.ltb p", "N.eqb p") if lang == "r" else ("p <", "p ==")
    return (f"(if {lt} {ps[m]} then\n{sp}  {disp_rl(ps[:m], ind + 1, lang)}\n{sp}else if {eq} {ps[m]} then "
            f"p{ps[m]} c\n{sp}else\n{sp}  {disp_rl(ps[m + 1:], ind + 1, lang)})")


HDR = ("generated by cases/gen2.py from tables.txt (Oniguruma f95747b's\n"
       "   unicode_fold_data.c, unicode_property_data.c and unicode.c;\n"
       "   Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause; Unicode data)")


def rocq_tables(folds, ranges, props):
    o = [f"(* {HDR} *)\nFrom Stdlib Require Import List NArith.\nImport ListNotations.\n\n"]
    o.append("Definition fold_of (c : N) : list N :=\n  " +
             tree_fold_rl(sorted(folds), folds, 1, "r") + ".\n\n")
    for p in props:
        o.append(f"Definition p{p} (c : N) : bool :=\n  {tree_ranges_rl(ranges[p], 1, 'r')}.\n\n")
    o.append("Definition in_prop (p c : N) : bool :=\n  " + disp_rl(sorted(props), 1, "r") + ".\n")
    return "".join(o)


def lean_tables(folds, ranges, props):
    o = [f"/- {HDR} -/\nnamespace Tables\n\n"]
    o.append("def foldOf (c : Nat) : List Nat :=\n  " +
             tree_fold_rl(sorted(folds), folds, 1, "l") + "\n\n")
    for p in props:
        o.append(f"def p{p} (c : Nat) : Bool :=\n  {tree_ranges_rl(ranges[p], 1, 'l')}\n\n")
    o.append("def inProp (p c : Nat) : Bool :=\n  " + disp_rl(sorted(props), 1, "l") + "\n\nend Tables\n")
    return "".join(o)


def why3_tables(folds, ranges, props):
    o = ["(* generated by cases/gen2.py from tables.txt (Oniguruma f95747b's\n"
         "   unicode_fold_data.c, unicode_property_data.c and unicode.c;\n"
         "   Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause; Unicode data) *)\n"
         "module Tables\n  use int.Int\n\n  type bytes = BNil | BCons int bytes\n\n"]
    o.append("  let fold_of (c : int) : bytes =\n    " +
             tree_fold(sorted(folds), folds, 2, "w") + "\n\n")
    for p in props:
        o.append(f"  let p{p} (c : int) : bool =\n    {tree_ranges(ranges[p], 2)}\n\n")
    # dispatch on the ctype: a balanced tree as well
    def disp(ps, ind):
        if not ps: return "false"
        m = len(ps) // 2
        sp = "  " * ind
        return (f"(if p < {ps[m]} then\n{sp}  {disp(ps[:m], ind + 1)}\n{sp}else if p = {ps[m]} then "
                f"p{ps[m]} c\n{sp}else\n{sp}  {disp(ps[m + 1:], ind + 1)})")
    o.append("  let in_prop (p c : int) : bool =\n    " + disp(sorted(props), 2) + "\nend\n")
    return "".join(o)


def fstar_tables(folds, ranges, props):
    o = ["module Tables\n(* generated by cases/gen2.py from tables.txt (Oniguruma f95747b's\n"
         "   unicode_fold_data.c, unicode_property_data.c and unicode.c;\n"
         "   Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause; Unicode data) *)\n\n"]
    o.append("let fold_of (c:int) : list int =\n  " +
             tree_fold(sorted(folds), folds, 1, "f") + "\n\n")
    for p in props:
        o.append(f"let p{p} (c:int) : bool =\n  {tree_ranges(ranges[p], 1)}\n\n")
    def disp(ps, ind):
        if not ps: return "false"
        m = len(ps) // 2
        sp = "  " * ind
        return (f"(if p < {ps[m]} then\n{sp}  {disp(ps[:m], ind + 1)}\n{sp}else if p = {ps[m]} then "
                f"p{ps[m]} c\n{sp}else\n{sp}  {disp(ps[m + 1:], ind + 1)})")
    o.append("let in_prop (p c:int) : bool =\n  " + disp(sorted(props), 1) + "\n")
    return "".join(o)

ICHUNK = 32


def isa_tree(keys, mk, leaf, empty, name, defs, ret, arg="c"):
    """balanced decision tree over sorted keys as Isabelle definitions:
    subtrees of at most ICHUNK keys become definitions of their own, so
    that no term is large (Isabelle's inner syntax)"""
    def go(ks, top):
        if not ks:
            return empty
        if len(ks) <= ICHUNK and not top:
            nm = f"{name}_{len(defs)}"
            body = inline(ks, 1)
            defs.append(f'definition {nm} :: "nat \\<Rightarrow> {ret}" where\n'
                        f'  "{nm} {arg} = {body}"\n\n')
            return f"{nm} {arg}"
        m = len(ks) // 2
        return mk(ks[m], go(ks[:m], False), go(ks[m + 1:], False))
    def inline(ks, ind):
        if not ks:
            return empty
        m = len(ks) // 2
        return mk(ks[m], inline(ks[:m], ind + 1), inline(ks[m + 1:], ind + 1))
    return go(keys, True)


def isa_tables(folds, ranges, props):
    defs = []
    o = [f"(* {HDR} *)\ntheory Tables\n  imports Main \"HOL-Library.Code_Target_Numeral\"\nbegin\n\n"]
    fk = sorted(folds)
    fmk = lambda k, l, r: (f"(if c < {k} then {l} else if c = {k} then {i_nlist(folds[k])} else {r})")
    root = isa_tree(fk, fmk, None, "[c]", "fold_t", defs, "nat list")
    o.extend(defs); defs.clear()
    o.append(f'definition fold_of :: "nat \\<Rightarrow> nat list" where\n  "fold_of c = {root}"\n\n')
    for p in props:
        rs = ranges[p]
        rmk = lambda r, l, rr: (f"(if c < {r[0]} then {l} else if c \\<le> {r[1]} then True else {rr})")
        root = isa_tree(rs, rmk, None, "False", f"p{p}_t", defs, "bool")
        o.extend(defs); defs.clear()
        o.append(f'definition p{p} :: "nat \\<Rightarrow> bool" where\n  "p{p} c = {root}"\n\n')
    def disp(ps):
        if not ps: return "False"
        m = len(ps) // 2
        return (f"(if p < {ps[m]} then {disp(ps[:m])} else if p = {ps[m]} then p{ps[m]} c "
                f"else {disp(ps[m + 1:])})")
    o.append('definition in_prop :: "nat \\<Rightarrow> nat \\<Rightarrow> bool" where\n'
             f'  "in_prop p c = {disp(sorted(props))}"\n\nend\n')
    return "".join(o)


def rust_tables(folds, ranges, props):
    o = [f"// {HDR.replace(chr(10) + '   ', chr(10) + '// ')}\nuse vstd::prelude::*;\n\nverus! {{\n\n"]
    def ftree(ks, ind):
        sp = "    " * ind
        if not ks:
            return "(c, 0, 0, 1)"
        m = len(ks) // 2
        k = ks[m]
        v = folds[k]
        assert 1 <= len(v) <= 3, (k, v)
        w = v + [0] * (3 - len(v))
        return (f"if c < {k} {{\n{sp}    {ftree(ks[:m], ind + 1)}\n{sp}}} else if c == {k} {{ "
                f"({w[0]}, {w[1]}, {w[2]}, {len(v)}) }} else {{\n{sp}    {ftree(ks[m + 1:], ind + 1)}\n{sp}}}")
    o.append("#[verifier::external_body]\npub fn fold_of(c: u32) -> (r: (u32, u32, u32, usize))\n"
             "    ensures r.3 <= 3,\n{\n    " + ftree(sorted(folds), 1) + "\n}\n\n")
    def rtree(rs, ind):
        sp = "    " * ind
        if not rs:
            return "false"
        m = len(rs) // 2
        lo, hi = rs[m]
        return (f"if c < {lo} {{\n{sp}    {rtree(rs[:m], ind + 1)}\n{sp}}} else if c <= {hi} {{ true }} "
                f"else {{\n{sp}    {rtree(rs[m + 1:], ind + 1)}\n{sp}}}")
    for p in props:
        o.append(f"#[verifier::external_body]\nfn p{p}(c: u32) -> bool {{\n    {rtree(ranges[p], 1)}\n}}\n\n")
    def disp(ps, ind):
        sp = "    " * ind
        if not ps: return "false"
        m = len(ps) // 2
        return (f"if p < {ps[m]} {{\n{sp}    {disp(ps[:m], ind + 1)}\n{sp}}} else if p == {ps[m]} {{ "
                f"p{ps[m]}(c) }} else {{\n{sp}    {disp(ps[m + 1:], ind + 1)}\n{sp}}}")
    o.append("#[verifier::external_body]\npub fn in_prop(p: u32, c: u32) -> bool {\n    "
             + disp(sorted(props), 1) + "\n}\n\n} // verus!\n")
    return "".join(o)


# ---- case modules -----------------------------------------------------


def why3_cases(cases):
    o = ["(* generated by cases/gen2.py: one function per case and a balanced\n"
         "   dispatch on the index, no nested list constant (experiment #7's\n"
         "   interpreter bug) *)\nmodule Cases2\n  use int.Int\n  use tables.Tables\n"
         "  use spec2.Spec2\n\n"]
    for i, (_, n, refs, a, s, e) in enumerate(cases):
        o.append(f"  let c{i} () : case =\n    Case {n} {w_list(refs)} {w_node(a)} "
                 f"{w_list(s)} {w_list(e)}\n")
    o.append(f"\n  let constant ncases : int = {len(cases)}\n\n")
    def disp(lo, hi, ind):
        if lo == hi: return f"c{lo} ()"
        m = (lo + hi + 1) // 2
        sp = "  " * ind
        return (f"(if i < {m} then\n{sp}  {disp(lo, m - 1, ind + 1)}\n{sp}else\n{sp}  {disp(m, hi, ind + 1)})")
    o.append("  let get (i : int) : case =\n    " + disp(0, len(cases) - 1, 2) + "\n\n")
    o.append("  let rec count_from (fuel : int) (i : int) (acc : int) : int\n"
             "    requires { 0 <= i <= ncases && fuel >= 0 } variant { ncases - i } =\n"
             "    if i = ncases then acc\n"
             "    else count_from fuel (i + 1) (if agree fuel (get i) then acc + 1 else acc)\n\n"
             "  let rec passes (r : int) (acc : int) : int\n"
             "    requires { r >= 0 } variant { r } =\n"
             "    if r = 0 then acc else passes (r - 1) (acc + count_from (fuel0 + r) 0 0)\n\n"
             "  (* the first [m] cases only (calibration on a prefix) *)\n"
             "  let rec count_prefix (fuel : int) (i m : int) (acc : int) : int\n"
             "    requires { 0 <= i <= m && fuel >= 0 } variant { m - i } =\n"
             "    if i = m then acc\n"
             "    else count_prefix fuel (i + 1) m (if agree fuel (get i) then acc + 1 else acc)\n"
             "end\n")
    return "".join(o)


def fstar_cases(cases):
    o = ["module Cases\n(* generated by cases/gen2.py *)\nopen Spec2\n\n"
         "let cases : list case = [\n"]
    o.append(";\n".join(
        f"  ({n}, {f_ints(refs)}, {f_node(a)}, {f_ints(s)}, {f_ints(e)})"
        for _, n, refs, a, s, e in cases))
    o.append("\n]\n")
    return "".join(o)


CHUNK = 50


def rocq_cases(cases):
    o = ["(* generated by cases/gen2.py *)\nFrom Stdlib Require Import List NArith.\n"
         "From S Require Import Spec2.\nImport ListNotations.\n\n"]
    names = []
    for j in range(0, len(cases), CHUNK):
        names.append(f"cases{j // CHUNK}")
        o.append(f"Definition {names[-1]} : list case := [\n")
        o.append(";\n".join(
            f"  ({n}, {r_list([str(x) for x in refs])}, {r_node(a)}, {r_nlist(s)}, "
            f"{r_list([str(x) for x in e])})"
            for _, n, refs, a, s, e in cases[j:j + CHUNK]))
        o.append("\n].\n\n")
    o.append("Definition cases : list case :=\n  " + " ++\n  ".join(names or ["[]"]) + ".\n")
    return "".join(o)


def lean_cases(cases):
    o = ["-- generated by cases/gen2.py\nimport Spec2\nopen Spec2\n\n"]
    names = []
    for j in range(0, len(cases), CHUNK):
        names.append(f"cases{j // CHUNK}")
        o.append(f"def {names[-1]} : List Case := [\n")
        o.append(",\n".join(
            f"  ({n}, {l_nlist(refs)}, {l_node(a)}, {l_nlist(s)}, {l_nlist(e)})"
            for _, n, refs, a, s, e in cases[j:j + CHUNK]))
        o.append("\n]\n\n")
    o.append("def cases : List Case :=\n  " + " ++\n  ".join(names or ["[]"]) + "\n")
    return "".join(o)


def isa_cases(cases):
    o = ["(* generated by cases/gen2.py *)\ntheory Cases\n  imports Spec2\nbegin\n\n"]
    names = []
    for j in range(0, len(cases), CHUNK):
        names.append(f"cases{j // CHUNK}")
        o.append(f'definition {names[-1]} :: "tcase list" where\n  "{names[-1]} = [\n')
        o.append(",\n".join(
            f"  ({n}, {i_nlist(refs)}, {i_node(a)}, {i_nlist(s)}, {i_nlist(e)})"
            for _, n, refs, a, s, e in cases[j:j + CHUNK]))
        o.append(']"\n\n')
    o.append('definition cases :: "tcase list" where\n  "cases = ' + " @\n    ".join(names or ["[]"]) + '"\n\nend\n')
    return "".join(o)


def rust_cases(cases):
    o = ["// generated by cases/gen2.py\nuse crate::spec2::{Case, CSet, Node, Re};\n\n"]
    names = []
    for j in range(0, len(cases), CHUNK):
        names.append(f"cases{j // CHUNK}")
        o.append(f"#[allow(unused_imports)]\nfn {names[-1]}(v: &mut Vec<Case>) {{\n")
        for _, n, refs, ast, s, e in cases[j:j + CHUNK]:
            a, root = rust_arena2(ast)
            pools = ", ".join(f"{k}: vec![{', '.join(a[k])}]" for k in
                              ("nodes", "bytes", "cps", "seqs", "kids", "gidx", "csets", "cidx"))
            o.append(f"    v.push(Case {{ ncap: {n}, refs: vec![{', '.join(map(str, refs))}], "
                     f"re: Re {{ {pools}, root: {root} }}, s: vec![{', '.join(map(str, s))}], "
                     f"exp: vec![{', '.join(map(str, e))}] }});\n")
        o.append("}\n\n")
    o.append("#[allow(unused_imports)]\npub fn cases() -> Vec<Case> {\n    let mut v = Vec::new();\n"
             + "".join(f"    {nm}(&mut v);\n" for nm in names) + "    v\n}\n")
    return "".join(o)


def main():
    inf, orf, tbf, out = sys.argv[1:5]
    heavy = len(sys.argv) > 5
    verd = dict(l.rstrip("\n").split("\t", 1) for l in open(orf))
    cases, used = [], {12}
    for l in open(inf):
        f = l.rstrip("\n").split("\t")
        cid, sub = f[1], f[4]
        ncap, ast = int(f[10]), f[11]
        if ast == "!":
            continue
        a = parse(ast)
        used |= props_of(a)
        cases.append((cid, ncap, refs_of(a), a, list(bytes.fromhex(sub)),
                      expected(verd[cid], ncap)))
    folds, ranges = load_tables(tbf)
    os.makedirs(out, exist_ok=True)
    for kind, props in (("restricted", sorted(used)), ("full", sorted(ranges))):
        os.makedirs(f"{out}/{kind}", exist_ok=True)
        open(f"{out}/{kind}/tables.mlw", "w").write(why3_tables(folds, ranges, props))
        open(f"{out}/{kind}/Tables.fst", "w").write(fstar_tables(folds, ranges, props))
        open(f"{out}/{kind}/Tables.v", "w").write(rocq_tables(folds, ranges, props))
        open(f"{out}/{kind}/Tables.lean", "w").write(lean_tables(folds, ranges, props))
        open(f"{out}/{kind}/Tables.thy", "w").write(isa_tables(folds, ranges, props))
        open(f"{out}/{kind}/tables2.rs", "w").write(rust_tables(folds, ranges, props))
    open(f"{out}/used-ctypes.txt", "w").write(" ".join(map(str, sorted(used))) + "\n")
    def write(d, cs):
        os.makedirs(d, exist_ok=True)
        open(f"{d}/ids.txt", "w").write("".join(c[0] + "\n" for c in cs))
        open(f"{d}/cases.mlw", "w").write(why3_cases(cs))
        open(f"{d}/Cases.fst", "w").write(fstar_cases(cs))
        open(f"{d}/Cases.v", "w").write(rocq_cases(cs))
        open(f"{d}/Cases.lean", "w").write(lean_cases(cs))
        open(f"{d}/Cases.thy", "w").write(isa_cases(cs))
        open(f"{d}/cases2.rs", "w").write(rust_cases(cs))
    write(out, cases)
    msg = f"{len(cases)} cases; ctypes used {len(used)}; full table {len(ranges)} ctypes"
    if heavy:
        hv = [c for c in cases if props_of(c[3])]
        write(f"{out}/heavy", hv)
        msg += f"; property-heavy cases {len(hv)}"
    print(msg, file=sys.stderr)


if __name__ == "__main__":
    main()
