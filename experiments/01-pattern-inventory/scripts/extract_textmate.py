#!/usr/bin/env python3
# Extract match/begin/end/while patterns from VS Code's *.tmLanguage.json.
# Usage: extract_textmate.py VSCODE_CHECKOUT > patterns/vscode.occurrences.jsonl
#
# Host configuration (vscode-oniguruma OnigScanner defaults, used by
# vscode-textmate): ONIG_SYNTAX_DEFAULT (= ONIGURUMA), ONIG_OPTION_CAPTURE_GROUP,
# UTF-8.  "pattern" is the compiled form vscode-textmate hands to Oniguruma
# for the \A-and-\G-allowed scanner variant: \z rewritten to $(?!\n)(?<!\n)
# (vscode-textmate src/rule.ts RegExpSource), and, for end/while patterns
# with \N references to begin captures, each \N replaced by the empty
# string (what resolveBackReferences yields for an empty capture).
import json, re, sys, pathlib

ONIG_OPTION_CAPTURE_GROUP = 256
HAS_BACKREF = re.compile(r'\\(\d+)')

def compiled_form(src):
    out, i, n = [], 0, len(src)
    last = 0
    while i < n:
        if src[i] == '\\' and i + 1 < n:
            if src[i + 1] == 'z':
                out.append(src[last:i]); out.append('$(?!\\n)(?<!\\n)'); last = i + 2
            i += 2
            continue
        i += 1
    out.append(src[last:])
    return ''.join(out)

def walk(node, path, emit):
    if isinstance(node, dict):
        for k, v in node.items():
            p = f"{path}/{k}"
            if k in ('match', 'begin', 'end', 'while') and isinstance(v, str):
                emit(k, p, v, node)
            else:
                walk(v, p, emit)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, f"{path}/{i}", emit)

def main():
    root = pathlib.Path(sys.argv[1])
    files = sorted(root.glob('extensions/*/syntaxes/*.tmLanguage.json'))
    for f in files:
        rel = f.relative_to(root).as_posix()
        g = json.loads(f.read_text(encoding='utf-8'))
        def emit(key, path, v, node):
            hostsub = key in ('end', 'while') and 'begin' in node and HAS_BACKREF.search(v) is not None
            pat = compiled_form(v)
            if hostsub:
                pat = HAS_BACKREF.sub('', pat)
            rec = {
                'source': 'vscode', 'file': rel, 'loc': path, 'key': key,
                'raw': v, 'pattern': pat, 'syntax': 'ONIGURUMA',
                'options': ONIG_OPTION_CAPTURE_GROUP, 'encoding': 'UTF-8',
                'status': 'host-substituted' if hostsub else 'literal',
                'rewritten_z': '\\z' in v and pat != v,
            }
            print(json.dumps(rec, ensure_ascii=False))
        walk(g, '', emit)

main()
