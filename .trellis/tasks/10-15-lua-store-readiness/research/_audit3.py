import json, re, io, sys
from collections import Counter, defaultdict
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BASE = r"D:/MyNewProjects/qfli_studio_core/assets/content"
def load(p):
    with open(p, encoding='utf-8') as f: return json.load(f)
tut = load(f"{BASE}/tutorials.json"); ex = load(f"{BASE}/examples.json")
lt = [e for e in tut['entries'] if e.get('language','').lower()=='lua']
le = [e for e in ex['entries'] if e.get('language','').lower()=='lua']

print("=== tutorial level -> id ranges ===")
bylv = defaultdict(list)
for e in lt: bylv[e['level']].append(e['id'])
for k,v in bylv.items(): print(k, len(v), v[0], '..', v[-1])

print("\n=== code shape: how many match the weighted-sum template? ===")
tmpl = re.compile(r'^local values = \{\d+, \d+, \d+\}\nlocal total = 0\nfor position, value in ipairs\(values\) do total = total \+ value \* position end\nprint\("weighted=" \.\. total\)$')
matches = [e['id'] for e in lt if tmpl.match(e['lessons'][0]['code'])]
print("weighted-sum template count:", len(matches), "/", len(lt))
print("non-template:", [e['id'] for e in lt if e['id'] not in matches])

print("\n=== distinct code first-lines (shape) ===")
shapes = Counter()
for e in lt:
    c = e['lessons'][0]['code']
    shapes[re.sub(r'\d+', 'N', c.split('\n')[0])] += 1
for s,c in shapes.most_common(): print(f"{c:3d}  {s}")

print("\n=== every tutorial: does code cover its stated topic? ===")
kw = {
 '数据建模':'table','输入校验':'assert|type|error','文件格式':'io.open',
 '日志':'print|io.write','缓存':'cache','队列':'queue|insert|remove',
 '分页':'sort','配置':'config','并发':'coroutine','测试':'assert',
 '性能':'os.clock','安全':'sandbox','网络':'socket','持久化':'io',
 '命令行':'arg','模块':'require','状态机':'state','时间':'os.date',
 '文本':'string','故障':'pcall','资源打包':'package','增量':'diff',
 'API':'require','重构':'function',
}
# topic is title after 'Lua NNN: '
def topic(e): return e['title'].split(':',1)[1].strip()
aligned = 0; mismatched = []
for e in lt:
    t = topic(e); code = e['lessons'][0]['code']
    pat = None
    for k,v in kw.items():
        if k in t: pat = v; break
    if pat and re.search(pat, code): aligned += 1
    else: mismatched.append((e['id'], t, pat))
print("aligned:", aligned, "/", len(lt))
print("mismatched (id, topic, expected-pattern):")
for m in mismatched[:30]: print("  ", m)
