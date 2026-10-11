import sys, os; sys.path.insert(0,''+__import__('os').path.dirname(__import__('os').path.abspath(__file__))+'')
import numpy as np
from PIL import Image
from fit import body_canvas, fit_layer, VIEWS
A=__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', '..', 'assets', 'sprites')
SCALE=3
LAYERS={('gear','hide_wrap'):'armor_hide',('gear','leather_armor'):'armor_leather',('clothing','fur_cloak'):'cloak_fur',
        ('hair','long'):'hair_long',('hair','braids'):'hair_braids',('clothing','animal_hood'):'hood_wolf',
        ('clothing','antler_skull'):'helm_antler',('gear','spear'):'spear',('gear','bone_spear'):'spear_bone',
        ('gear','hide_shield'):'shield_wood',('gear','bone_shield'):'shield_bone'}
SKINS={'skin1':(0.95,0.82,0.71),'skin2':(0.88,0.70,0.56),'skin3':(0.76,0.57,0.42),'skin4':(0.60,0.42,0.29),'skin5':(0.44,0.30,0.20),'skin6':(0.31,0.21,0.15)}
HAIRS={'black':(0.16,0.13,0.12),'brown':(0.40,0.26,0.16),'auburn':(0.60,0.28,0.14),'blond':(0.88,0.74,0.44),'grey':(0.66,0.64,0.61)}
def hsv(a):
    f=a[...,:3].astype(float)/255; mx=f.max(axis=-1); mn=f.min(axis=-1)
    return mx, np.where(mx>0,(mx-mn)/np.maximum(mx,1e-6),0)
def skin_mask(a):
    v,s=hsv(a); r,g,b=(a[...,i].astype(int) for i in range(3))
    return (a[...,3]>0)&(v>=0.42)&(s>0.3)&(r>=g)&(g>=b)
def hair_mask(a, region=None):
    v,s=hsv(a); m=(a[...,3]>0)&(v<0.40)&(v>0.13)
    return m&region if region is not None else m
def recolor(a, mask, target, strength=1.0):
    """Give masked pixels the target color, keeping their light and shade."""
    if not mask.any(): return a
    out=a.astype(float); v,_=hsv(a); base=v[mask].mean(); t=np.array(target)*255
    for ch in range(3):
        new=np.clip(t[ch]*(v[mask]/base),0,255)
        out[...,ch][mask]=a[...,ch][mask]*(1-strength)+new*strength
    return out.astype(np.uint8)
def save(arr, cat, piece, view):
    d=f'{A}/{cat}/{piece}'; os.makedirs(d,exist_ok=True); Image.fromarray(arr).save(f'{d}/{view}.png')
for v in VIEWS:
    canvas,(ox,oy),(bw,bh)=body_canvas(v)
    layers={k:fit_layer(row,v) for k,row in LAYERS.items()}
    union=canvas[...,3]>0
    for arr in layers.values(): union|=arr[...,3]>0
    ys,xs=np.nonzero(union); feet=oy+bh; cx=ox+bw/2
    half=int(np.ceil(max(cx-xs.min(), xs.max()+1-cx)/SCALE))*SCALE
    top=feet-((feet-ys.min()+SCALE-1)//SCALE)*SCALE
    box=(int(cx-half), int(top), int(cx+half), int(feet))
    def finish(arr):
        im=Image.fromarray(arr).crop(box); return np.asarray(im.resize((im.width//SCALE, im.height//SCALE), Image.NEAREST))
    head=np.zeros(canvas.shape[:2],bool); head[oy:oy+42,:]=True
    hm=hair_mask(canvas, head); sm=skin_mask(canvas)&~hm
    for sk,sc in SKINS.items():
        skinned=recolor(canvas, sm, sc, 0.85)
        for hk,hc in HAIRS.items():
            save(finish(recolor(skinned, hm, hc)),'bodies',f'body_male__{sk}__{hk}',v)
    save(finish(canvas),'bodies','body_male',v)
    for (cat,piece),arr in layers.items():
        if cat=='hair':
            for hk,hc in HAIRS.items():
                save(finish(recolor(arr, hair_mask(arr), hc)),cat,f'{piece}__{hk}',v)
        save(finish(arr),cat,piece,v)
print('done')
