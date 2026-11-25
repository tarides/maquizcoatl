"""Lemma count and automatic share (plan step 6, experiment #9).

Usage: python3 -I lemmas.py <file.v>...   (Rocq; F* and Verus are added
when their M2 closes)

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


def main(paths):
    tot = [0, 0, 0]
    for p in paths:
        ls = lemmas(p)
        for name, auto, adm, n in ls:
            print(f"{p}\t{name}\t{'automatic' if auto else ('ADMITTED' if adm else 'manual')}\t{n}")
        a = sum(1 for x in ls if x[1]); d = sum(1 for x in ls if x[2])
        print(f"{p}\ttotal {len(ls)}\tautomatic {a}\tadmitted {d}")
        tot[0] += len(ls); tot[1] += a; tot[2] += d
    print(f"all\ttotal {tot[0]}\tautomatic {tot[1]}\tadmitted {tot[2]}")


if __name__ == "__main__":
    main(sys.argv[1:])
