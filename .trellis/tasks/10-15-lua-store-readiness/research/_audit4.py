import json, re, io, sys
from collections import Counter
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BASE = r"D:/MyNewProjects/qfli_studio_core/assets/content"
def load(p):
    with open(p, encoding='utf-8') as f: return json.load(f)
ex = load(f"{BASE}/examples.json")
le = [e for e in ex['entries'] if e.get('language','').lower()=='lua']

print("=== Lua examples: id / level / title / code first line ===")
for e in le:
    first = e['code'].split('\n')[0]
    print(f"[{e['id']}] {e['level']:12s} {e['title']}")
    print(f"    code1={first!r}")
    print(f"    tmpl={e['templateType']!r} lesson={e['sourceLessonId']!r} fixtures={e['inputFixtures']}")
    print(f"    exp={e['expectedOutput']!r}")

print("\n=== code shape counts ===")
shapes = Counter()
for e in le:
    shapes[re.sub(r'\d+','N',e['code'].split('\n')[0])] += 1
for s,c in shapes.most_common(): print(f"{c:3d}  {s}")

print("\n=== unique code count:", len(set(e['code'] for e in le)))
print("=== empty code count:", sum(1 for e in le if not e['code'].strip()))
print("=== unique expectedOutput:", len(set(e['expectedOutput'] for e in le)))
print("=== templateType values:", Counter(e['templateType'] for e in le))
print("=== example levels:", Counter(e['level'] for e in le))
