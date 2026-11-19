#!/bin/bash
# Steps 4-6 on the bench host: emit, fidelity (with the generator on UCD
# 16.0.0), C oracle on the sample.  Output in $EXP/out/fidelity/.
set -euo pipefail
EXP=${EXP:-$HOME/maquizcoatl-work/exp/07-large-tables}
L=$(cd "$(dirname "$0")" && pwd)
SRC=$EXP/repo/upstream/src
O=$EXP/out/fidelity; mkdir -p "$O" "$EXP/gen" "$EXP/ucd"
cd "$EXP/ucd"
U=https://www.unicode.org/Public/16.0.0/ucd
for f in UnicodeData DerivedCoreProperties Scripts PropList PropertyAliases PropertyValueAliases Blocks auxiliary/GraphemeBreakProperty emoji/emoji-data; do
  b=$(basename $f).txt; [ -f $b ] || curl -fsSL -o $b $U/$f.txt
done
sha256sum *.txt > "$O/ucd.sha256"
cp "$SRC/make_unicode_property_data.py" "$EXP/gen/"; cp "$EXP"/ucd/*.txt "$EXP/gen/"
(cd "$EXP/gen" && python3 -I make_unicode_property_data.py > generated.gperf)
python3 -I "$L/fidelity.py" "$SRC/unicode_property_data.c" "$EXP/gen/generated.gperf" | tee "$O/fidelity.tsv"
python3 -I "$L/emit.py" "$SRC/unicode_property_data.c" "$EXP/emit" > "$O/emitted.tsv"
python3 -I "$L/sample.py" gen "$EXP/emit/table.json" "$EXP/sample" | tee "$O/sample.txt"
B=$EXP/build/onig
gcc -O2 -I"$SRC" -I"$B" -o "$EXP/oracle" "$L/oracle.c" "$B/libonig.a" 2>/dev/null || \
gcc -O2 -I"$SRC" -I"$B" -o "$EXP/oracle" "$L/oracle.c" -L"$B" -lonig -Wl,-rpath,"$B"
cd "$EXP/sample"
"$EXP/oracle" queries.txt names.txt oracle.txt is_code_ctype.txt 2> "$O/is_code_ctype-diff.txt"
python3 -I "$L/sample.py" compare expected.txt oracle.txt | tee "$O/oracle-vs-parsed.txt"
sha256sum queries.txt names.txt oracle.txt is_code_ctype.txt > "$O/sample.sha256"
