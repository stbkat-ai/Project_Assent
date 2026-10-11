import numpy as np, sys
from PIL import Image
sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from slice_sheet import background_mask
img=Image.open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', '..', 'assets', 'source', 'sheet_paper_doll_male.png')).convert('RGBA')
a=np.asarray(img).copy(); rgb=a[...,:3].astype(int)
bg=background_mask(img,(255,0,255),80)|((rgb[...,0]-rgb[...,1]>70)&(rgb[...,2]-rgb[...,1]>70))
white=(rgb.min(axis=2)>200)&((rgb.max(axis=2)-rgb.min(axis=2))<40)
a[bg|white]=0
ys=[1,141,230,318,399,487,571,647,740,821,900,980,1073,1197]; xs=[0,263,525,786,1048,1311]
NAMES=['body','armor_hide','cloak_fur','armor_leather','hair_long','hair_braids','hair_mixed','helm_antler','hood_wolf','spear','spear_bone','shield_wood','shield_bone']
VIEWS=['s','se','e','ne','n']
def cell(name, view, biggest_only=True):
    r=NAMES.index(name); c=VIEWS.index(view)
    cl=a[ys[r]+3:ys[r+1]-2, xs[c]+3:xs[c+1]-2].copy()
    m=cl[...,3]>0
    if biggest_only:
        # keep the largest blob (drops stray specks / line remnants)
        from collections import deque
        lab=np.full(m.shape,-1); best=None; bi=-1; k=0
        for y,x in zip(*np.nonzero(m)):
            if lab[y,x]!=-1: continue
            q=deque([(y,x)]); lab[y,x]=k; n=0
            while q:
                cy,cx=q.popleft(); n+=1
                for dy in (-1,0,1):
                    for dx in (-1,0,1):
                        ny,nx=cy+dy,cx+dx
                        if 0<=ny<m.shape[0] and 0<=nx<m.shape[1] and m[ny,nx] and lab[ny,nx]==-1:
                            lab[ny,nx]=k; q.append((ny,nx))
            if best is None or n>best: best=n; bi=k
            k+=1
        sizes=np.bincount(lab[lab>=0])
        keep=np.isin(lab, np.nonzero(sizes>=max(30,best*0.02))[0])
        cl[~keep]=0; m=keep
    yy,xx=np.nonzero(m)
    return cl[yy.min():yy.max()+1, xx.min():xx.max()+1]
