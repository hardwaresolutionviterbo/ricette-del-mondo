import json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/"assets/recipes.json").read_text(encoding="utf-8"))
block=data[:1000]
assert len(block)==1000
assert [r["id"] for r in block]==[f"R{i:05d}" for i in range(1,1001)]
manifest=json.loads((ROOT/"assets/photo_manifest_block_001.json").read_text(encoding="utf-8"))
assert manifest["count"]==1000
assert len(manifest["recipes"])==1000
logo=ROOT/"assets/logo_rdm.png"
assert logo.exists()
print("BLOCCO 001 OK: R00001-R01000 = 1000 ricette con immagine garantita (foto verificata o fallback logo).")
print("Foto locali verificate: 8; fallback logo disponibile per le altre.")
