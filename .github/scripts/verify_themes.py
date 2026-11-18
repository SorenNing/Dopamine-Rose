#!/usr/bin/env python3
"""Verify the actual RootHide archive and the native four-theme UI resources."""
from pathlib import Path, PurePosixPath
import hashlib, json, plistlib, struct, sys, zipfile

archive = Path(sys.argv[1])
base = 'Payload/Dopamine.app/'
with zipfile.ZipFile(archive) as z:
    names = z.namelist()
    assert z.testzip() is None and len(names) == len(set(names)), 'ZIP integrity'
    assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in names)
    info = plistlib.loads(z.read(base + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'cn.zqbb.dopaRH'
    assert info['CFBundleShortVersionString'] == '3.0.13-30'
    assert int(info['DOBuildTimestamp']) > 0
    themes = plistlib.loads(z.read(base + 'Themes.plist'))
    assert [t['key'] for t in themes] == ['origami', 'glaze', 'nocturne', 'dusty-rose']
    assert [t['darkTheme'] for t in themes] == [False, False, True, False]
    assert [t['panelColor'] for t in themes] == ['4AFFFFFB', '4AFFFFFB', '0EE4E6E3', '4AFFF8FA']
    assert [t['image'] for t in themes] == ['Background_Origami', 'Background_Glaze', 'Background_Nocturne', 'Background_DustyRose']
    assert all(not {'liquidGlass', 'usesTheseus', 'glassBlurRadius'} & t.keys() for t in themes)
    assert base + 'default.metallib' not in names
    assert base + 'Dopamine.roothide' in names
    for n in ('libchoma.dylib', 'libxpf.dylib', 'libjailbreak.dylib', 'libroothider.dylib', 'Assets.car', 'basebin.tar', 'bootstrap_1900.tar.zst', 'roothideapp.deb'):
        assert z.getinfo(base + n).file_size > 0, n
    assert base + 'bootstrap_1800.tar.zst' not in names
    assert not any('/palera1n.framework/' in n for n in names)
    executable = z.read(base + info['CFBundleExecutable'])
    for marker in (b'brandCardView', b'contentViewForController:', b'makeInformationCard', b'restartCardWithAction:subtitle:', b'showResultTitle:failed:', b'selectTopLevelTab:'):
        assert marker in executable, marker
    for marker in (b'DOTheseusGlassView', b'DOTheseusTabBar', b'configureWithTitles:symbolNames:selectedIndex:'):
        assert marker not in executable, marker
    assert b'GLSGlassView' not in executable
    assert b'_displayCornerRadius' not in executable
    assert b'_frameForViewController:' not in executable
    assert b'contentFrameForViewController:' not in executable
    assert b'makeBottomBar' not in executable
    images = {}
    required_images = ['Dopamine', 'libchoma.dylib', 'libxpf.dylib', 'libjailbreak.dylib', 'libroothider.dylib']
    for name in names:
        if not name.startswith(base + 'Frameworks/') or name.endswith('/'):
            continue
        if z.read(name)[:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
            required_images.append(name[len(base):])
    for n in required_images:
        data = z.read(base + n)
        magic = data[:4]
        if magic == b'\xcf\xfa\xed\xfe':
            slices = [(0, len(data))]
        elif magic == b'\xca\xfe\xba\xbe':
            count = struct.unpack_from('>I', data, 4)[0]
            assert 0 < count < 10
            slices = [struct.unpack_from('>II', data, 16 + 20 * i) for i in range(count)]
        else:
            raise AssertionError((n, 'unexpected Mach-O'))
        details = []
        for offset, size in slices:
            header = struct.unpack_from('<8I', data, offset)
            assert header[0] == 0xfeedfacf and header[1] == 0x100000c
            assert offset + size <= len(data)
            cursor = offset + 32
            signed = False
            minimum_os = None
            for _ in range(header[4]):
                cmd, length = struct.unpack_from('<II', data, cursor)
                assert length >= 8 and cursor + length <= offset + 32 + header[5]
                if cmd == 0x32:
                    minimum_os = struct.unpack_from('<I', data, cursor + 12)[0]
                elif cmd == 0x25:
                    minimum_os = struct.unpack_from('<I', data, cursor + 8)[0]
                if cmd == 0x1d:
                    start, length_sign = struct.unpack_from('<II', data, cursor + 8)
                    assert 0 < length_sign and start + length_sign <= size
                    signed = True
                cursor += length
            assert signed, (n, 'missing signature')
            assert minimum_os is not None and minimum_os <= 0x000f0000, (n, 'deployment target', hex(minimum_os or 0))
            details.append({'cpu_subtype': hex(header[2]), 'size': size, 'minimum_os': hex(minimum_os)})
        images[n] = {'sha256': hashlib.sha256(data).hexdigest(), 'slices': details}
result = {'archive': archive.name, 'bytes': archive.stat().st_size, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'bundle': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'], 'themes': [t['key'] for t in themes], 'images': images, 'device_tested': False}
archive.with_suffix('.verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
