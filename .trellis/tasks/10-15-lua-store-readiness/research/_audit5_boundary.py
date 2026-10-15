import json, hashlib, io, sys
from collections import Counter
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BASE = r"D:/MyNewProjects/qfli_studio_core/assets/content"

def load(p):
    with open(p, 'rb') as f: raw = f.read()
    return json.loads(raw.decode('utf-8')), raw

for name in ['tutorials.json', 'examples.json']:
    doc, raw = load(f"{BASE}/{name}")
    entries = doc['entries']
    lua = [e for e in entries if e.get('language') == 'lua']
    non = [e for e in entries if e.get('language') != 'lua']
    # fingerprint of non-lua rows preserving order
    h = hashlib.sha256()
    for e in non:
        h.update(json.dumps(e, ensure_ascii=False, sort_keys=True).encode('utf-8'))
    print(f"{name}: total={len(entries)} lua={len(lua)} non_lua={len(non)}")
    print(f"  non_lua_fingerprint={h.hexdigest()[:32]}")
    print(f"  top-level keys={list(doc.keys())}")
    print(f"  updatedAt={doc.get('updatedAt')} schemaVersion={doc.get('schemaVersion')} kind={doc.get('kind')}")

# Lua first/last positions in file (line numbers) for precise edit boundary
for name in ['tutorials.json', 'examples.json']:
    with open(f"{BASE}/{name}", encoding='utf-8') as f:
        lines = f.readlines()
    print(f"\n{name}: {len(lines)} lines")
    # find 'lua-tutorial-001' / 'lua-example-001' line
    for i, l in enumerate(lines, 1):
        if 'lua-tutorial-001"' in l or 'lua-example-001"' in l:
            print(f"  first lua entry at line {i}: {l.strip()[:60]}")
            break
    for i, l in enumerate(lines, 1):
        if 'lua-tutorial-100"' in l or 'lua-example-100"' in l:
            print(f"  last lua entry at line {i}: {l.strip()[:60]}")
            break
