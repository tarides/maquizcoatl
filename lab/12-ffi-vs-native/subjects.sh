#!/bin/sh
# Build the large subjects of experiment #12 (1 MiB and 16 MiB cuts at a
# line boundary) from the OCaml 5.4.1 source tarball and the Loghub SSH log.
# Usage: CACHE=<cache> EXP=<exp> subjects.sh
set -eu
: "${CACHE:?}" "${EXP:?}"
TS="taskset -c 0-3,32-35"
OCAML_SHA=d4528517aaa1a44b8e2b1bc109a1ed0a5e0014f3ddc4feb8906b11a7e063e89a
LOG_URL="https://zenodo.org/records/8196385/files/SSH.tar.gz?download=1"
mkdir -p "$EXP/dl/ocaml" "$EXP/dl/loghub" "$EXP/subjects"
tarball=$(find "$CACHE/opam/download-cache" -name $OCAML_SHA | head -1)
echo "$OCAML_SHA  $tarball" | sha256sum -c - >/dev/null && echo "ocaml tarball sha256 ok"
[ -d "$EXP/dl/ocaml/ocaml-5.4.1" ] || $TS tar xzf "$tarball" -C "$EXP/dl/ocaml"
# whole .ml .mli .c .h files, sorted by path (C locale), concatenated
(cd "$EXP/dl/ocaml" && find ocaml-5.4.1 -type f \( -name '*.ml' -o -name '*.mli' -o -name '*.c' -o -name '*.h' \) | LC_ALL=C sort) > "$EXP/dl/ocaml/files.txt"
python3 -I - "$EXP" <<'PY'
import sys, os
exp = sys.argv[1]
def cut(data, size):
    if len(data) < size:
        return None
    k = data.rfind(b"\n", 0, size)
    return data[:k + 1]
# source files: whole files until the size is reached
files = open(os.path.join(exp, "dl/ocaml/files.txt")).read().split()
for size, name in ((1 << 20, "src-1m"), (16 << 20, "src-16m")):
    buf = bytearray()
    for f in files:
        if len(buf) >= size:
            break
        buf += open(os.path.join(exp, "dl/ocaml", f), "rb").read()
    if len(buf) < size:
        print(name, "MISSING: corpus too small", len(buf))
        continue
    open(os.path.join(exp, "subjects", name), "wb").write(cut(bytes(buf), size))
PY
if [ ! -f "$EXP/dl/loghub/SSH.tar.gz" ]; then
  curl -sSL --fail -o "$EXP/dl/loghub/SSH.tar.gz" "$LOG_URL" || echo "loghub download FAILED"
fi
if [ -f "$EXP/dl/loghub/SSH.tar.gz" ]; then
  sha256sum "$EXP/dl/loghub/SSH.tar.gz" | cut -d' ' -f1 > "$EXP/dl/loghub/SSH.tar.gz.sha256"
  (cd "$EXP/dl/loghub" && $TS tar xzf SSH.tar.gz)
  log=$(find "$EXP/dl/loghub" -name 'SSH.log' | head -1)
  python3 -I - "$log" "$EXP/subjects" <<'PY'
import sys, os
data = open(sys.argv[1], "rb").read()
for size, name in ((1 << 20, "log-1m"), (16 << 20, "log-16m")):
    if len(data) < size:
        print(name, "MISSING: log too small", len(data)); continue
    k = data.rfind(b"\n", 0, size)
    open(os.path.join(sys.argv[2], name), "wb").write(data[:k + 1])
PY
fi
cd "$EXP/subjects"
for f in log-* src-*; do
  printf '%s bytes=%s lines=%s sha256=%s ascii=%s\n' "$f" "$(stat -c %s "$f")" "$(wc -l < "$f")" \
    "$(sha256sum "$f" | cut -d' ' -f1)" "$(LC_ALL=C grep -c -P '[^\x00-\x7f]' "$f" | sed 's/^0$/yes/;s/^[1-9][0-9]*$/no/')"
done > "$EXP/subjects/manifest.txt"
cat "$EXP/subjects/manifest.txt"
