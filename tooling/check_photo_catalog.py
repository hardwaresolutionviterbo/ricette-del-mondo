import json, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT/'assets/recipes.json').read_text(encoding='utf-8'))
ids = [r.get('id','') for r in data]
assert len(data) == 10000, len(data)
assert len(set(ids)) == len(ids)

photo_dir = ROOT/'assets/images'
files = [p for p in photo_dir.iterdir() if p.is_file()] if photo_dir.exists() else []
hashes = {}
for p in files:
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    hashes.setdefault(h, []).append(p.name)
dups = {h:n for h,n in hashes.items() if len(n)>1}

print(f'catalogo: {len(data)}')
print(f'asset immagini locali: {len(files)}')
print(f'duplicati binari locali: {len(dups)}')
if dups:
    for names in dups.values(): print('DUP:', ', '.join(names))
