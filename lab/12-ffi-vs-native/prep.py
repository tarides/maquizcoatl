#!/usr/bin/env python3
"""Experiment #12: flatten experiment #1's workloads into the work format
read by the OCaml harness and the C driver.

usage: python3 -I prep.py DATA_DIR OUT_DIR

Writes OUT_DIR/{jq,php,vscode,longphp}.all.work (every call, before the
subset classifier), OUT_DIR/{jq,php,longphp}.expected.tsv and
OUT_DIR/vscode.lines.tsv.

Work format (one record per line, strings in hex):
  P pid syntax options retry_limit stack_limit hexpattern
  S sid hexsubject
  C cid pid sid kind start range search_options weight
syntax: 0 ONIGURUMA, 1 RUBY, 2 PERL_NG, 9 other syntax, 8 non-UTF-8
encoding (both rejected by the classifier).  kind: 0 search, 1 match.
"""
import json, os, sys

SYN = {"ONIGURUMA": 0, "RUBY": 1, "PERL_NG": 2}
DEFAULT_RETRY = 10_000_000


def pat_bytes(t):
    if t.get("pattern") is not None:
        return t["pattern"].encode("utf-8", "surrogatepass")
    return bytes.fromhex(t["pattern_hex"])


def subj_bytes(c):
    if c.get("subject_hex"):
        return bytes.fromhex(c["subject_hex"])
    return c["subject"].encode("utf-8", "surrogatepass")


class Work:
    def __init__(self):
        self.pats, self.subs, self.cases = {}, {}, []

    def pid(self, t, mp):
        syn = SYN.get(t["syntax"], 9) if t["encoding"] == "UTF-8" else 8
        lim = (mp or {}).get("retry_limit_in_match", DEFAULT_RETRY)
        stk = (mp or {}).get("match_stack_limit", 0)
        key = (syn, t["options"], lim, stk, pat_bytes(t))
        if key not in self.pats:
            self.pats[key] = len(self.pats)
        return self.pats[key]

    def sid(self, b):
        if b not in self.subs:
            self.subs[b] = len(self.subs)
        return self.subs[b]

    def write(self, path):
        with open(path, "w") as f:
            for (syn, opt, lim, stk, pb), pid in self.pats.items():
                f.write(f"P {pid} {syn} {opt} {lim} {stk} {pb.hex()}\n")
            for b, sid in self.subs.items():
                f.write(f"S {sid} {b.hex()}\n")
            for c in self.cases:
                f.write("C %d %d %d %d %d %d %d %d\n" % c)


def simple(data, out, fam):
    w = Work()
    with open(os.path.join(out, fam + ".expected.tsv"), "w") as ex:
        for i, line in enumerate(open(os.path.join(data, fam + ".jsonl"))):
            c = json.loads(line)
            pid = w.pid(c["triple"], c["match_param"])
            sid = w.sid(subj_bytes(c))
            kind = 0 if c["kind"] == "search" else 1
            rng = c["range"] if c["range"] is not None else 0
            w.cases.append((i, pid, sid, kind, c["start"], rng, c["search_options"], 1))
            e = c["expected"]
            m = e.get("match") or [-1, -1]
            ex.write(f"{i}\t{e['result']}\t{m[0]}\t{m[1]}\n")
    w.write(os.path.join(out, fam + ".all.work"))


def longphp(data, out):
    w = Work()
    subj = {}
    for line in open(os.path.join(data, "php.long-subjects.subjects.jsonl")):
        s = json.loads(line)
        subj[s["subject_id"]] = (s["repeat"]["unit"] * s["repeat"]["count"]).encode()
    with open(os.path.join(out, "longphp.expected.tsv"), "w") as ex:
        for i, line in enumerate(open(os.path.join(data, "php.long-subjects.jsonl"))):
            c = json.loads(line)
            pid = w.pid(c["triple"], c["match_param"])
            sid = w.sid(subj[c["subject_id"]])
            kind = 0 if c["kind"] == "search" else 1
            rng = c["range"] if c["range"] is not None else 0
            w.cases.append((i, pid, sid, kind, c["start"], rng, c["search_options"], 1))
            e = c["expected"]
            m = e.get("match") or [-1, -1]
            ex.write(f"{i}\t{e['result']}\t{m[0]}\t{m[1]}\n")
    w.write(os.path.join(out, "longphp.all.work"))


def vscode(data, out):
    triples = {}
    for line in open(os.path.join(data, "vscode.triples.jsonl")):
        t = json.loads(line)
        triples[t["id"]] = t
    scanners = {}
    for line in open(os.path.join(data, "vscode.scanners.jsonl")):
        s = json.loads(line)
        scanners[s["scanner"]] = s["members"]
    freq = [json.loads(l) for l in open(os.path.join(data, "vscode.frequency.jsonl"))]
    w = Work()
    cid = 0
    with open(os.path.join(out, "vscode.lines.tsv"), "w") as lt:
        for i, line in enumerate(open(os.path.join(data, "vscode.jsonl"))):
            c = json.loads(line)
            f = freq[i]
            assert f["line"] == i and f["scanner"] == c["scanner"] and f["start"] == c["start"]
            sid = w.sid(subj_bytes(c))
            cids = []
            for tid in scanners[c["scanner"]]:
                pid = w.pid(triples[tid], c["match_param"])
                w.cases.append((cid, pid, sid, 0, c["start"], c["range"], c["search_options"], f["count"]))
                cids.append(str(cid))
                cid += 1
            e = c["expected"]
            m = e.get("match") or [-1, -1]
            lt.write(f"{i}\t{f['count']}\t{e['index']}\t{m[0]}\t{m[1]}\t{','.join(cids)}\n")
    w.write(os.path.join(out, "vscode.all.work"))


def main():
    data, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    simple(data, out, "jq")
    simple(data, out, "php")
    longphp(data, out)
    vscode(data, out)


if __name__ == "__main__":
    main()
