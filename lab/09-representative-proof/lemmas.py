"""Lemma count and automatic share (plan step 6, experiment #9).

Usage: python3 -I lemmas.py <file.v|file.fst>...   (Rocq; F* added in
run 7; Verus is added when its M2 closes)

A lemma is a named statement: Rocq `Lemma`, `Theorem`, `Corollary`,
`Fact`, `Proposition` (not `Example`, `Definition`, `Fixpoint`,
`Inductive`). It is automatic when its proof, between `Proof.` and
`Qed.`, is one call of an automation tactic (`lia`, `auto`, `eauto`,
`easy`, `congruence`, `intuition`, `firstorder`), possibly with hints
(`auto with arith`, `eauto using foo`): one sentence, no `;`, no other
tactic. A proof ending in `Admitted.` is counted apart and is never
closed. Comments are stripped first (loc.py's rule).

Prints one line per lemma (file, name, automatic or not, tactic
sentences in the proof) and the totals per file and overall.

F* (.fst, run 7): a lemma is a top-level `let` (or `val`) whose type is
a `Lemma` (the word `Lemma` at bracket depth 0 in the declaration's
head, before the `=` that starts its body). It is automatic when its
body is `()`: the default SMT discharge, with no explicit call to
another lemma (plan step 6). A top-level `let` of a proof module whose
type is not a `Lemma` is printed with kind `function` (a total function
that returns witnesses, such as `ProofSim.sim`, or an auxiliary
definition) or `example` (an `assert_norm`), with its line count, and
is not a lemma. Comments are stripped first (loc.py's rule); for every
item the third column is its kind and the fourth its non-blank lines.
"""
import re
import sys

AUTO = re.compile(r"^(lia|auto|eauto|easy|congruence|intuition|firstorder)"
                  r"(\s+(with|using)\s+[\w\s,.']+)?\s*\.$")
DECL = re.compile(r"(?m)^\s*(Lemma|Theorem|Corollary|Fact|Proposition)\s+([\w']+)")
END = re.compile(r"\b(Qed|Defined|Admitted)\s*\.")


def strip_comments(text):
    out, depth, i = [], 0, 0
    while i < len(text):
        if text.startswith("(*", i):
            depth += 1; i += 2; continue
        if depth and text.startswith("*)", i):
            depth -= 1; i += 2; continue
        if not depth:
            out.append(text[i])
        elif text[i] == "\n":
            out.append("\n")
        i += 1
    return "".join(out)


def sentences(body):
    # split on '.' followed by whitespace or end (not inside identifiers
    # such as Nat.add_0_r); bullets and braces are not sentences
    parts = re.split(r"\.(?=\s|$)", body)
    out = []
    for p in parts:
        p = re.sub(r"^[\s\-+*{}]+", "", p).strip()
        if p:
            out.append(p + ".")
    return out


def lemmas(path):
    text = strip_comments(open(path, encoding="utf-8").read())
    res = []
    for m in DECL.finditer(text):
        name = m.group(2)
        pr = text.find("Proof.", m.end())
        e = END.search(text, pr)
        body = text[pr + len("Proof."):e.start()]
        sents = sentences(body)
        admitted = e.group(1) == "Admitted"
        auto = (not admitted and len(sents) == 1 and ";" not in sents[0]
                and AUTO.match(" ".join(sents[0].split())) is not None)
        res.append((name, auto, admitted, len(sents)))
    return res


FTOP = re.compile(r"(?m)^(let|val|type|noeq|open|module|#push-options|#pop-options|\[@@)")


def fstar_head_body(decl):
    """Split a declaration at the first '=' at bracket depth 0 that is
    not part of an operator (==, <==>, ==>, <=, >=, =~)."""
    depth = 0
    for i, ch in enumerate(decl):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "=" and depth == 0:
            prev = decl[i - 1] if i else " "
            nxt = decl[i + 1] if i + 1 < len(decl) else " "
            if prev in "=<>!" or nxt in "=>~":
                continue
            return decl[:i], decl[i + 1:]
    return decl, ""


def depth0(text):
    out, depth = [], 0
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif depth == 0:
            out.append(ch)
    return "".join(out)


def fstar_items(path):
    text = strip_comments(open(path, encoding="utf-8").read())
    starts = [m.start() for m in FTOP.finditer(text)] + [len(text)]
    res = []
    for a, b in zip(starts, starts[1:]):
        decl = text[a:b]
        m = re.match(r"(let|val)\s+(rec\s+)?([\w']+)", decl)
        if not m:
            continue
        name = m.group(3)
        head, body = fstar_head_body(decl)
        nlines = sum(1 for ln in decl.split("\n") if ln.strip())
        if re.search(r"\bLemma\b", depth0(head)):
            kind = "automatic" if body.strip() == "()" else "manual"
        elif body.strip().startswith("assert_norm"):
            kind = "example"
        else:
            kind = "function"
        res.append((name, kind, nlines))
    return res


def main(paths):
    tot = [0, 0, 0]
    for p in paths:
        if p.endswith(".fst"):
            its = fstar_items(p)
            for name, kind, n in its:
                print(f"{p}\t{name}\t{kind}\t{n}")
            nl = sum(1 for x in its if x[1] in ("automatic", "manual"))
            na = sum(1 for x in its if x[1] == "automatic")
            nf = sum(1 for x in its if x[1] == "function")
            print(f"{p}\ttotal {nl}\tautomatic {na}\tadmitted 0\tfunctions {nf}")
            tot[0] += nl; tot[1] += na
            continue
        ls = lemmas(p)
        for name, auto, adm, n in ls:
            print(f"{p}\t{name}\t{'automatic' if auto else ('ADMITTED' if adm else 'manual')}\t{n}")
        a = sum(1 for x in ls if x[1]); d = sum(1 for x in ls if x[2])
        print(f"{p}\ttotal {len(ls)}\tautomatic {a}\tadmitted {d}")
        tot[0] += len(ls); tot[1] += a; tot[2] += d
    print(f"all\ttotal {tot[0]}\tautomatic {tot[1]}\tadmitted {tot[2]}")


if __name__ == "__main__":
    main(sys.argv[1:])
