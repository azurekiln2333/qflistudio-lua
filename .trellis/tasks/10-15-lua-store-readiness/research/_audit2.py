import json, re, io, sys
from collections import Counter

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BASE = r"D:/MyNewProjects/qfli_studio_core/assets/content"
def load(p):
    with open(p, encoding='utf-8') as f: return json.load(f)
tut = load(f"{BASE}/tutorials.json"); ex = load(f"{BASE}/examples.json")
lt = [e for e in tut['entries'] if e.get('language','').lower()=='lua']
le = [e for e in ex['entries'] if e.get('language','').lower()=='lua']

print("=== first 12 Lua tutorials ===")
for e in lt[:12]:
    l = e['lessons'][0]
    print(f"[{e['id']}] level={e['level']}  title={e['title']}")
    print(f"    lesson.id={l['id']}  lesson.title={l['title']}")
    print(f"    summary={l['summary'][:80]}")
    print(f"    code={l['code']!r}")
    print(f"    output={l['output']!r}")
print("\n=== lesson titles frequency ===")
for t,c in Counter(l['title'] for e in lt for l in e['lessons']).most_common():
    print(f"{c:3d}  {t}")
print("\n=== unique explain values:", len(set(l['explain'] for e in lt for l in e['lessons'])))
print("unique lesson summary:", len(set(l['summary'] for e in lt for l in e['lessons'])))
print("\n=== all tutorial ids ===")
print([e['id'] for e in lt])
print("\n=== all example ids ===")
print([e['id'] for e in le])
