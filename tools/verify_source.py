#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[1]
m=json.loads((R/'reviewed-source.json').read_text())
for name,digest in m['files'].items():
 p=R/name
 assert p.is_file(),name
 assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,name
for name,sha in m['submodules'].items():
 actual=subprocess.check_output(['git','-C',str(R/name),'rev-parse','HEAD'],text=True).strip()
 assert actual==sha,(name,actual,sha)
print('Verified',len(m['files']),'source files and',len(m['submodules']),'submodule commits')
