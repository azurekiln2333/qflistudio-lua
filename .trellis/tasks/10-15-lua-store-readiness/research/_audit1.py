import json, re, hashlib, sys
from collections import Counter, defaultdict

BASE = r"D:/MyNewProjects/qfli_studio_core/assets/content"

def load(p):
    with open(p, encoding='utf-8') as f:
        return json.load(f)

tut = load(f"{BASE}/tutorials.json")
ex = load(f"{BASE}/examples.json")

def lua_entries(doc):
    return [e for e in doc['entries'] if (e.get('language') or '').lower() == 'lua']

lt = lua_entries(tut)
le = lua_entries(ex)
print("=== Lua counts ===")
print("tutorial entries:", len(lt), " example entries:", len(le))

def norm(s):
    if not isinstance(s, str): return ''
    return re.sub(r'\s+', ' ', s.strip())

print("\n=== Tutorial structure ===")
keys = Counter()
levels = Counter()
total_lessons = 0
for e in lt:
    keys.update(e.keys())
    levels[e.get('level')] += 1
    total_lessons += len(e.get('lessons', []))
print("keys:", dict(keys))
print("levels:", dict(levels))
print("total lessons:", total_lessons)
print("avg lessons/tutorial:", round(total_lessons/len(lt),2))

# duplicate detection
def dup_report(items, fields):
    print(f"\n--- duplicate report on {fields} ---")
    for f in fields:
        c = Counter(norm(i.get(f)) for i in items)
        dups = {k:v for k,v in c.items() if v>1 and k}
        print(f"field {f}: {len(dups)} duplicated values, top5: {sorted(dups.items(), key=lambda x:-x[1])[:5]}")

dup_report(lt, ['title','summary'])
all_lessons = []
for e in lt:
    for l in e.get('lessons', []):
        all_lessons.append(l)
print("\nlessons total:", len(all_lessons))
dup_report(all_lessons, ['title','code','output','explain','summary'])

print("\n=== Example structure ===")
ekeys = Counter()
for e in le: ekeys.update(e.keys())
print("keys:", dict(ekeys))
dup_report(le, ['title','summary','code','expectedOutput'])
