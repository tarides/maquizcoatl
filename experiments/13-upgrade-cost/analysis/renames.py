# For every classified row with lines, list renames git -M finds in its units.
import csv, subprocess, sys, glob, os
R = sys.argv[1]  # lab/results dir
C = sys.argv[2]  # clones dir
clone = {'warblre':'Warblre','linden':'Linden','lean-regex':'lean-regex','everparse-cbor':'everparse','creusot':'creusot','anvil':'anvil'}
def git(repo, *a):
    return subprocess.run(['git','-C',os.path.join(C,repo)]+list(a),capture_output=True,text=True,check=True).stdout
def full(repo,u):
    return git(repo,'rev-parse',u).strip()
out=csv.writer(sys.stdout)
out.writerow(['project','unit','renamed_pairs','renamed_paths','lines_no_renames','lines_with_renames'])
for p,repo in clone.items():
    f=os.path.join(R,f'2026-11-19-exp-13-{p}-rerun-bumps.csv')
    for row in csv.DictReader(open(f)):
        if not row['class'] or row['class']=='': continue
        for u in row['units'].split('; '):
            h=full(repo,u)
            parent=h+'^1'
            nr=git(repo,'diff','--numstat','--no-renames',parent,h)
            m=git(repo,'diff','--numstat','-M',parent,h)
            ren=[l for l in m.splitlines() if '=>' in l]
            if not ren: continue
            # lines of renamed pairs, both ways
            pairs=[]
            tot_m=0; tot_nr=0
            nrmap={}
            for l in nr.splitlines():
                a,d,path=l.split('\t',2)
                nrmap[path]=(0 if a=='-' else int(a))+(0 if d=='-' else int(d))
            for l in ren:
                a,d,path=l.split('\t',2)
                lm=(0 if a=='-' else int(a))+(0 if d=='-' else int(d))
                # expand {x => y}
                import re
                mm=re.match(r'(.*)\{(.*) => (.*)\}(.*)',path)
                if mm:
                    old=(mm[1]+mm[2]+mm[4]).replace('//','/'); new=(mm[1]+mm[3]+mm[4]).replace('//','/')
                else:
                    old,new=path.split(' => ')
                tot_m+=lm; tot_nr+=nrmap.get(old,0)+nrmap.get(new,0)
                pairs.append(f'{old}->{new}')
            out.writerow([p,u,len(pairs),' | '.join(pairs)[:600],tot_nr,tot_m])
