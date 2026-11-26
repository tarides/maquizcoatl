"""Hand check of lemmas.py's Verus body rule (issue #34, run-3 review fixes).

Usage: python3 -I realbody.py <dir of lemmas.py> <file.rs>...

lemmas.py takes the first brace block at bracket depth 0 after a
`proof fn` name as its body. A brace block inside `requires`/`ensures`
(`if ... { } else { }`, `match ... { }`, `==> { &&& ... }`) is followed by
`,`, `else`, another clause keyword or another block; this check skips
such blocks and takes the first one that is followed by none of them.
Same comment stripping and same non-blank-line count as lemmas.py.
Prints file, name, kind, lines, and lemmas.py's kind and lines where they
differ. lemmas.py itself is not changed.
"""
import re, sys
sys.path.insert(0, sys.argv[1])
import lemmas as L

for p in sys.argv[2:]:
    text = open(p, encoding="utf-8").read()
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    script = {n: (k, c) for n, k, c, _ in L.verus_items(p)}
    for m in L.VTOP.finditer(text):
        i, depth = m.end(), 0
        while True:
            ch = text[i]
            if ch == "{" and depth == 0:
                k, d = i, 0
                while True:
                    if text[k] == "{":
                        d += 1
                    elif text[k] == "}":
                        d -= 1
                        if d == 0:
                            break
                    k += 1
                after = text[k + 1:].lstrip()
                if after[:1] in (",", "{") or re.match(r"(else|ensures|decreases|returns)\b", after):
                    i = k + 1
                    continue
                break
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            i += 1
        body = text[i + 1:k]
        n = sum(1 for ln in text[m.start():k + 1].split("\n") if ln.strip())
        sk, sc = script[m.group(3)]
        kind = "example" if sk == "example" else ("automatic" if not body.strip() else "manual")
        diff = "" if (sk, sc) == (kind, n) else f"\tlemmas.py: {sk} {sc}"
        print(f"{p.split('/')[-1]}\t{m.group(3)}\t{kind}\t{n}{diff}")
