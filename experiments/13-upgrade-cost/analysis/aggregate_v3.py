# Aggregates the v3 per-series table per project (experiment #13 mining v3).
import csv, sys, statistics as st
rows = list(csv.DictReader(open(sys.argv[1])))
size = {'warblre':8864,'linden':24108,'lean-regex':13701,'everparse-cbor':126578,
        'why3-gallery':101344,'creusot':94430,'anvil':85908,'afp-regex':23162}
cad = {'rocq':2,'lean':11,'fstar':28,'why3':1,'verus':52,'isabelle':3}
anvil_releases = 49  # Verus stable releases 2025-11-19..2026-10-12
w = csv.writer(sys.stdout)
w.writerow(['project','tool','kloc','releases_crossed','median_hand_per_release','mean_hand_per_release',
            'released_hand','unreleased_hand','other_hand','yearly_hand','yearly_total','optional','raw',
            'yearly_hand_per_kloc','mean_hand_per_release_per_kloc'])
for p in size:
    rs = [r for r in rows if r['project']==p]
    vals = []
    for r in rs:
        if r['bucket']=='released':
            n=int(r['releases_spanned']); vals += [float(r['adaptation_hand'])/n]*n
    tool = rs[0]['tool']
    sumb = lambda b, c='adaptation_hand': sum(float(r[c]) for r in rs if r['bucket']==b)
    hand = sum(float(r['adaptation_hand']) for r in rs)
    total = sum(float(r['adaptation_total']) for r in rs)
    opt = sum(float(r['optional']) for r in rs)
    raw = sum(float(r['raw_lines']) for r in rs)
    k = size[p]/1000
    if p=='anvil':
        n = anvil_releases; med=''; mean = hand/n
    elif vals:
        n=len(vals); med=round(st.median(vals),1); mean=sum(vals)/n
    else:
        n=0; med=''; mean=None
    w.writerow([p,tool,round(k,1),n,med,'' if mean is None else round(mean,1),
                sumb('released')+sumb('anvil'),sumb('unreleased'),sumb('other'),round(hand,1),round(total,1),opt,int(raw),
                round(hand/k,1),'' if mean is None else round(mean/k,2)])
