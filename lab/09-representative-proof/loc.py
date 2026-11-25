"""Lines of specification, proof and test cases, per tool and feature.

Usage: python3 -I loc.py <file>...   (prints: file, spec, proof, cases)

Blank lines and comments are not counted. A line is classified by the
top-level declaration it belongs to (a declaration runs from its first
line to the line before the next top-level declaration):

- Rocq (.v): `Lemma`/`Theorem` statements and their `Proof.`...`Qed.`/
  `Defined.` blocks are proof; `Print Assumptions` lines are not counted.
- Lean (.lean): `theorem`/`lemma` declarations and their bodies are proof;
  `#print` lines are not counted.
- F* (.fst): `let`s with a `Lemma` type are proof, and so are
  `assert`/`calc` blocks (top-level `let x = assert_norm ...`).
- Verus (.rs): `proof fn` items (signature and body) are proof, and so are
  `assert` lines and `by` blocks inside other items.

Everything else that is not blank or a comment is specification. Proof
declarations whose name is a test-case id (ca01, nc03, ns01_4, ab05,
fl02, cf21, if07, ...) or `cases` are counted in the third column,
"cases", instead of "proof": they run the cases, they do not prove a
lemma. Definitions of the case data (patterns, subjects) are spec.
"""
import re
import sys

CASE = re.compile(r"^(ca|nc|ns|ab|fl|cf|if|lf)\d+(_\d+)?$|^cases$|^lemma_f\w*$")


def strip_comments(text, kind):
    if kind in ("v", "fst"):
        out, depth, i = [], 0, 0
        while i < len(text):
            if text.startswith("(*", i):
                depth += 1; i += 2; continue
            if depth and text.startswith("*)", i):
                depth -= 1; i += 2; continue
            if depth:
                out.append("\n" if text[i] == "\n" else ""); i += 1; continue
            out.append(text[i]); i += 1
        text = "".join(out)
        if kind == "fst":
            text = re.sub(r"//[^\n]*", "", text)
        return text
    if kind == "lean":
        text = re.sub(r"/-.*?-/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
        return re.sub(r"--[^\n]*", "", text)
    if kind == "rs":
        text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
        return re.sub(r"//[^\n]*", "", text)
    raise ValueError(kind)


TOP = {
    "v": re.compile(r"^(Lemma|Theorem|Definition|Fixpoint|Inductive|Section|End|Variables|From|Import|Print|Require|Open|Arguments|Proof|Qed)\b"),
    "lean": re.compile(r"^(theorem|lemma|def|inductive|structure|namespace|end|open|#print|#eval|set_option|instance|abbrev|private|noncomputable)\b"),
    "fst": re.compile(r"^(let|type|module|open|val|#push|#pop|#set)\b"),
    "rs": re.compile(r"^\s{0,4}(pub\s+)?(open\s+|closed\s+)?(spec\s+fn|proof\s+fn|fn|enum|struct|use|verus!|}\s*//\s*verus)\b"),
}


def classify(path):
    kind = path.rsplit(".", 1)[1]
    lines = strip_comments(open(path, encoding="utf-8").read(), kind).split("\n")
    counts = {"spec": 0, "proof": 0, "cases": 0}
    cur = "spec"
    in_proof_block = False
    for line in lines:
        s = line.strip()
        if not s:
            continue
        if kind == "v":
            if re.match(r"^(Lemma|Theorem)\s+(\w+)", s):
                name = re.match(r"^(Lemma|Theorem)\s+(\w+)", s).group(2)
                cur = "cases" if CASE.match(name) else "proof"
            elif s.startswith("Print"):
                continue
            elif TOP["v"].match(line) and not s.startswith(("Proof", "Qed")):
                cur = "spec"
            counts[cur] += 1
            if s.endswith(("Qed.", "Defined.")):
                cur = "spec"
        elif kind == "lean":
            mm = re.match(r"^(theorem|lemma)\s+([\w.]+)", line)
            if mm:
                cur = "cases" if CASE.match(mm.group(2).split(".")[-1]) else "proof"
            elif s.startswith("#print"):
                continue
            elif TOP["lean"].match(line):
                cur = "spec"
            counts[cur] += 1
        elif kind == "fst":
            mm = re.match(r"^let\s+(rec\s+)?(\w+)", line)
            if mm:
                name = mm.group(2)
                if CASE.match(name) or "assert_norm" in line:
                    cur = "cases"
                elif re.search(r":\s*Lemma\b", line) or "Lemma" in line:
                    cur = "proof"
                else:
                    cur = "spec"
            elif TOP["fst"].match(line):
                cur = "spec"
            if cur == "spec" and re.search(r"^\s*:?\s*(Lemma|\(requires|\(ensures)", line):
                cur = "proof"   # a let whose Lemma type is on the next line
            counts[cur] += 1
        else:  # rs
            mm = re.match(r"^\s*(pub\s+)?proof\s+fn\s+(\w+)", line)
            if mm:
                cur = "cases" if CASE.match(mm.group(2)) else "proof"
            elif TOP["rs"].match(line):
                cur = "spec"
            if cur == "spec" and re.match(r"^\s*assert\b", s):
                counts["proof"] += 1
                continue
            counts[cur] += 1
    return counts


if __name__ == "__main__":
    print("file\tspec\tproof\tcases")
    for f in sys.argv[1:]:
        c = classify(f)
        print(f"{f}\t{c['spec']}\t{c['proof']}\t{c['cases']}")
