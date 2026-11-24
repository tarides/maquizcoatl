# Mining summary v3 for experiment #13: applies the maintainer's methodology
# decisions (issue #3 comment 7017680025) to the classified per-release table.
# Input: lab/results/2026-11-19-exp-13-per-release-classified.csv (v2).
# Output (stdout): one CSV row per (project, series) with the v3 columns.
import csv, sys, statistics as st
src = sys.argv[1]
rows = list(csv.DictReader(open(src)))
# Per-series adjustments, in lines: (total adaptation, hand-written, optional,
# bucket). bucket: released (attributed to the series' releases), unreleased
# (series spanning no release: tracking unreleased versions), other.
adj = {
 # Warblre 9.1: rename detection (git diff -M) turns 950 lines of two renamed
 # files into 106: 1633 - 844 = 789. flake.lock (108, a lockfile) is not
 # hand-written: 681.
 ('warblre','9.1'): dict(total=789, hand=681),
 # EverParse 2026.10.11 (6c006b0): the tool gives it no span (its starting
 # F* pin is in no release): tracking unreleased versions.
 ('everparse-cbor','2026.10.11'): dict(bucket='unreleased'),
 # EverParse unattributed: 270f5aa (F* master after v2026.11.15) and
 # 56f47c8 (6). 270f5aa is a root-cause fix of 174 lines against an 8-line
 # workaround: 8 adaptation, 166 optional.
 ('everparse-cbor','unattributed'): dict(total=14, hand=14, optional=166, bucket='unreleased'),
 # Why3 gallery: 515 forced lines (upper bound), of which 358 regenerated
 # session lines; hand-written 157 (55 OCaml API, 60 certain + 42 uncertain .mlw).
 ('why3-gallery','1.9'): dict(total=515, hand=157),
 # Creusot 1.9: every pin is a commit already in 1.9.0 (span 0): tracking
 # unreleased versions. 992 lines, 23 hand-written (2 + 8 + 13).
 ('creusot','1.9'): dict(total=992, hand=23, bucket='unreleased'),
 # Anvil: optional cargo verus migration (0cd9f9f 3478, b1d8635 104,
 # 6096278 12) not counted; rename detection: Dockerfile rename in a65d68c
 # (16 lines to 0). b1d8635's own Dockerfile rename lowers the optional
 # figure to 88.
 ('anvil','0.2025.11.30.840fa61'): dict(total=2283, hand=2283, bucket='anvil'),
 ('anvil','0.2026.07.12.0b42f4c'): dict(bucket='anvil'),
 ('anvil','unattributed'): dict(total=5496-3478-104-12, hand=5496-3478-104-12, optional=3478+88+12, bucket='anvil'),
}
w = csv.writer(sys.stdout)
w.writerow(['project','tool','series','units','raw_lines','adaptation_v2','adaptation_total','adaptation_hand','optional','bucket','releases_spanned','hand_per_release','note'])
for r in rows:
    k = (r['project'], r['series'])
    a = adj.get(k, {})
    v2 = float(r['adaptation_lines'] or 0)
    total = a.get('total', v2); hand = a.get('hand', total)
    span = r['releases_spanned']
    bucket = a.get('bucket') or ('released' if span not in ('', '0') else 'other')
    hpr = round(hand/int(span),1) if bucket=='released' else ''
    w.writerow([r['project'],r['tool'],r['series'],r['units'],r['raw_lines'],r['adaptation_lines'],total,hand,a.get('optional',0),bucket,span,hpr,r['note']])
