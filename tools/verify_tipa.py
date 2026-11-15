#!/usr/bin/env python3
from pathlib import Path, PurePosixPath
import zipfile,plistlib,hashlib,json,struct,subprocess,tempfile,sys
R=Path(__file__).resolve().parents[1]
archive=Path(sys.argv[1]);prefix='Payload/Dopamine.app/'
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None,'ZIP CRC'
 names=z.namelist();assert len(names)==len(set(names)),'duplicate ZIP paths'
 for n in names:
  p=PurePosixPath(n);assert not p.is_absolute() and '..' not in p.parts,n
 info=plistlib.loads(z.read(prefix+'Info.plist'))
 assert info['CFBundleIdentifier']=='com.zqbb.Dopamine',info['CFBundleIdentifier']
 exe=z.read(prefix+info['CFBundleExecutable']);magic=exe[:4];slices=[]
 if magic==b'\xcf\xfa\xed\xfe':slices=[(0,len(exe))]
 elif magic==b'\xca\xfe\xba\xbe':
  count=struct.unpack_from('>I',exe,4)[0];assert 0<count<8
  for i in range(count):
   cpu,sub,off,size,align=struct.unpack_from('>IIIII',exe,8+i*20);slices.append((off,size))
 else:raise AssertionError('unexpected executable format')
 arch=[]
 for off,size in slices:
  assert off+size<=len(exe)
  m,cpu,sub,typ,ncmds,cmdsize,flags,reserved=struct.unpack_from('<8I',exe,off)
  assert m==0xfeedfacf and cpu==0x100000c and typ==2
  assert sub in (0,0x80000002),hex(sub)
  cur=off+32;sign=False
  for i in range(ncmds):
   cmd,sz=struct.unpack_from('<II',exe,cur);assert sz>=8 and cur+sz<=off+32+cmdsize
   if cmd==0x1d:
    do,ds=struct.unpack_from('<II',exe,cur+8);assert ds>0 and do+ds<=size;sign=True
   cur+=sz
  assert sign,'missing LC_CODE_SIGNATURE';arch.append({'cpu':hex(cpu),'subtype':hex(sub),'size':size})
 assert b'roseStateLabel' in exe and b'setupRoseStack' in exe,'Rose UI selectors'
 themes=plistlib.loads(z.read(prefix+'Themes.plist'));assert themes[0]['key']=='dusty-rose'
 assert prefix+'Assets.car' in names
 for resource in ['basebin.tar','bootstrap_1800.tar.zst','bootstrap_1900.tar.zst']:
  assert z.getinfo(prefix+resource).file_size>1024,resource
 for locale in ['en','zh-Hans','zh-CN','zh-HK','zh-TW']:
  data=z.read(prefix+locale+'.lproj/Localizable.strings')
  if data.startswith(b'bplist'):
   assert 'Rose_Status_Not_Jailbroken' in plistlib.loads(data)
  else:
   found=any('Rose_Status_Not_Jailbroken' in data.decode(e,errors='ignore') for e in ['utf-8','utf-16'])
   assert found,locale
 with tempfile.TemporaryDirectory(prefix='dopamine-verify-') as td:
  subprocess.run(['/usr/bin/ditto','-x','-k',str(archive.resolve()),td],check=True)
  app=Path(td)/'Payload/Dopamine.app'
  assert (app/'Dopamine').read_bytes()==exe
  subprocess.run(['codesign','--verify','--strict','--all-architectures',str(app/'Dopamine')],check=True)
  result=subprocess.run(['codesign','-d','--entitlements',':-',str(app/'Dopamine')],capture_output=True,check=True)
  ent=plistlib.loads(result.stdout)
  assert ent.get('com.apple.private.security.no-sandbox') is True,'sandbox entitlement'
receipt={'archive':archive.name,'size':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'bundle_identifier':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'executable_slices':arch,'zip_entries':len(names),'main_executable_codesign_verified':True,'device_tested':False}
archive.with_suffix('.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt,indent=2))
