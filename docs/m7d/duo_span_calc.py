import math
BASE={'week':(1400,1920),'day':(1000,2400)}
CAP={'week':3,'day':5}
def V(kind,W,H):
    bw,bh=BASE[kind]; z=min(W/bw,H/bh); return W/(bw*z), z
def R(v): return max(1, math.ceil((v-0.05)/2+1))
# plan.radius of the iPhone class rows (reference viewports), with cap (app passes overviewCap true)
REF={('portrait','week'):(402,540),('portrait','day'):(402,536),('landscape','week'):(874,205),('landscape','day'):(874,205)}
def plan_r(orient,kind):
    W,H=REF[(orient,kind)]; v,_=V(kind,W,H)
    if W>H: v=min(v,CAP[kind])
    return R(v)
def row(name,screen,W,H):
    orient='landscape' if screen[0]>screen[1] else 'portrait'
    out=[]
    for kind in ('week','day'):
        h=H if kind=='week' else H-4
        v,z=V(kind,W,h)
        capped = W>h   # maxVisiblePages: paper area wider than tall -> landscape -> cap
        vc=min(v,CAP[kind]) if capped else v
        capz = W/(CAP[kind]*BASE[kind][0])
        bites = capped and capz>z
        pr=plan_r(orient,kind)
        wr=max(pr,R(vc))
        hours = (h/ (capz if bites else z))/ (BASE[kind][1]/24)
        out.append(f"{kind}: area {W}x{h:.0f} minZ {z:.4f} V {v:.2f} cap {'bites' if bites else ('no' if capped else 'n/a')} Vc {vc:.2f} planR {pr} ({2*pr+1}p) liveR {wr} ({2*wr+1}p) hours-on-screen {min(24,hours):.1f}")
    print(f"{name} screen {screen[0]}x{screen[1]} ({orient})"); [print('   ',o) for o in out]
for (nm,scr,W,Hs) in [
  ('inner A portrait',(669,951),669,[951-334,951-255]),
  ('inner B portrait',(626,890),626,[890-334,890-255]),
  ('inner A landscape',(951,669),951,[669-223,669-197]),
  ('inner B landscape',(890,626),890,[626-223,626-197]),
  ('outer portrait',(466,678),466,[678-334]),
  ('outer landscape full-width',(678,466),678,[466-223,466-197]),
  ('outer landscape minus 124 side insets',(678,466),554,[466-223]),
  ('iPhone17 portrait ref',(402,874),402,[540]),
  ('iPhone17 landscape measured',(874,402),750,[179]),
]:
    for H in Hs: row(nm,scr,W,H)
