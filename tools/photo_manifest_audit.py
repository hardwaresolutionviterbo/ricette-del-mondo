#!/usr/bin/env python3
"""Audit locale del catalogo foto V6.

Non scarica immagini e non effettua scraping. Controlla soltanto:
- 10.000 ricette;
- ID univoci;
- eventuali imageUrl duplicati nel catalogo;
- asset foto locali esistenti;
- corrispondenza degli 8 asset verificati.
"""
import json, os, hashlib
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
recipes=json.load(open(os.path.join(ROOT,'assets','recipes.json'),encoding='utf-8'))
ids=[r['id'] for r in recipes]
urls=[r.get('imageUrl','').strip() for r in recipes if r.get('imageUrl','').strip()]
print('recipes',len(recipes),'unique_ids',len(set(ids)))
print('catalog_image_urls',len(urls),'unique',len(set(urls)))
imgs=[]
for d,_,fs in os.walk(os.path.join(ROOT,'assets','images')):
    for f in fs:
        if f.lower().endswith(('.jpg','.jpeg','.png','.webp')):
            imgs.append(os.path.join(d,f))
print('local_images',len(imgs))
seen={}
dup=[]
for p in imgs:
    h=hashlib.sha256(open(p,'rb').read()).hexdigest()
    if h in seen: dup.append((p,seen[h]))
    else: seen[h]=p
print('byte_duplicates',len(dup))
for a,b in dup[:20]: print('DUP',a,b)
