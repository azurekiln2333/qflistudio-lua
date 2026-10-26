"""Real-library smoke/regression probe; no Node or browser runtime."""
import ctypes as c
import json
import sys
import time
from pathlib import Path

class Result(c.Structure):
    _fields_ = [('status', c.c_int), ('output', c.c_void_p), ('error', c.c_void_p),
        ('diagnostics', c.c_void_p), ('output_length', c.c_size_t),
        ('error_length', c.c_size_t), ('diagnostics_length', c.c_size_t)]

root = Path(__file__).resolve().parents[2]
library = Path(sys.argv[1]) if len(sys.argv) > 1 else root/'native/build/script-windows/script/libqfli_script.dll'
lib = c.CDLL(str(library.resolve()))
lib.qfli_script_process.restype = c.POINTER(Result)
lib.qfli_script_process.argtypes = [c.c_char_p,c.c_size_t,c.c_char_p,c.c_char_p,c.c_char_p,c.c_size_t,c.c_char_p,c.c_size_t,c.c_int,c.c_int,c.c_int,c.c_int,c.c_void_p]
lib.qfli_script_free.argtypes = [c.POINTER(Result)]
compiler = (root/'assets/runtime/typescript.js').read_bytes()

def invoke(source, ts=False, action=0, docs=None, timeout=10000):
    text = source.encode()
    sources = json.dumps(docs or {}).encode()
    trusted = compiler if ts or any(k.endswith('.ts') for k in (docs or {})) else b''
    pointer = lib.qfli_script_process(text,len(text),b'/project/main.ts' if ts else b'/project/main.js',b'/project',sources,len(sources),trusted,len(trusted),int(ts),action,1,timeout,None)
    assert pointer
    value = pointer.contents
    result = {'status':value.status,'output':c.string_at(value.output,value.output_length).decode('utf8','replace'),
        'error':c.string_at(value.error,value.error_length).decode('utf8','replace'),
        'diagnostics':json.loads(c.string_at(value.diagnostics,value.diagnostics_length))}
    lib.qfli_script_free(pointer)
    return result

cases = [
 ('JS arrays/closures', 'console.log([1,2,3].map(x=>x*x).join(","));',False,0,0,'1,4,9\n'),
 ('JS syntax', 'const = nope',False,1,3,''),
 ('TS interfaces', 'interface V {n:number}\nconst v:V={n:42}; console.log(v.n);',True,0,0,'42\n'),
 ('TS syntax', 'const n: number = ;',True,1,3,''),
 ('No execution check', 'while(true) {}',False,1,0,''),
 ('Microtasks', 'await Promise.resolve(); console.log(42)',False,0,0,'42\n'),
 ('Timeout', 'while(true) {}',False,0,124,''),
]
def verify(name, source, ts=False, action=0, status=0, output='', docs=None, timeout=10000):
    start = time.monotonic()
    result = invoke(source,ts,action,docs=docs,timeout=timeout)
    print(name,round(time.monotonic()-start,3),json.dumps(result,ensure_ascii=True))
    assert result['status']==status and result['output']==output, name
    return result

for name,source,ts,action,status,output in cases:
    verify(name,source,ts,action,status,output,timeout=100 if status==124 else 10000)
verify('ES modules', 'import {square} from "./math.js"; console.log(square(7));',
    output='49\n', docs={'/project/math.js':'export const square = n => n*n;'})
verify('TS modules', 'import {value} from "./value.ts"; console.log(value);', True,
    output='42\n', docs={'/project/value.ts':'export const value: number = 42;'})
broken = verify('TS dependency diagnostic', 'import "./broken.ts";', True, status=3,
    docs={'/project/broken.ts': '// longer than entry\n' + ' '*100 + 'const n: number = ;'})
assert broken['diagnostics'][0]['filePath'] == '/project/broken.ts'
assert broken['error']
verify('Missing module', 'import "./missing.js";', status=1)
verify('Remote module', 'import "https://example.com/never.js";', status=1)
verify('Check imports not resolved/executed', 'import "./missing.js"; throw 42; while(true){}', action=1)
verify('TS semantic limits', 'const n: number = "not a number";', True, action=1)
verify('TS constructs', 'enum E { a=40,b } function identity<T>(x:T):T{return x;} console.log(identity(E.b)+1);', True, output='42\n')
verify('Unhandled rejection', 'Promise.reject(new Error("actual rejection"));', status=1)
pending = verify('Pending async', 'await new Promise(()=>{});', status=1)
assert pending['error'].endswith('unavailable host APIs\n')
verify('Embedded NUL output', 'console.log("中😀\\0尾");', output='中😀\0尾\n')
for prefix in ['// 中😀\r\n', '"😀"; ', '// 中\r', '// 中\n\r']:
    source = prefix + 'const = 1'
    result = verify('UTF16 exact positions', source, action=1, status=3)
    start = len(source[:source.index('=')].encode('utf-16-le'))//2
    assert result['diagnostics'][0]['startOffset'] == start
    assert result['diagnostics'][0]['endOffset'] == start+1
print('All native Script probes passed')
