#!/usr/bin/env python3
"""Sign nested Mach-O files first, then bundles, preserving existing entitlements."""
from pathlib import Path
import argparse, plistlib, struct, subprocess, tempfile

MAGICS = {b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'}

def entitlements(data):
    """Read each slice's XML entitlement blob without relying on signature trust."""
    if data[:4] == b'\xcf\xfa\xed\xfe':
        slices = [(0, len(data))]
    else:
        assert data[:4] in MAGICS, 'unsupported Mach-O'
        wide = data[:4] == b'\xca\xfe\xba\xbf'
        count = struct.unpack_from('>I', data, 4)[0]
        assert 0 < count <= 16
        slices = []
        for i in range(count):
            pos = 8 + i * (32 if wide else 20)
            off, size = struct.unpack_from('>QQ' if wide else '>II', data, pos + 8)
            slices.append((off, size))
    values = []
    for off, size in slices:
        assert 32 <= size and off + size <= len(data)
        assert data[off:off+4] == b'\xcf\xfa\xed\xfe'
        ncmds, cmdsize = struct.unpack_from('<II', data, off + 16)
        cursor = off + 32
        end = cursor + cmdsize
        assert end <= off + size
        value = {}
        signature_seen = False
        for _ in range(ncmds):
            assert cursor + 8 <= end
            cmd, length = struct.unpack_from('<II', data, cursor)
            assert length >= 8 and cursor + length <= end
            if cmd == 0x1d:
                assert length >= 16 and not signature_seen
                signature_seen = True
                start, total = struct.unpack_from('<II', data, cursor + 8)
                assert total >= 12 and start + total <= size
                start += off
                magic, blobsize, count = struct.unpack_from('>III', data, start)
                assert magic == 0xfade0cc0 and 12 + count * 8 <= blobsize <= total
                for i in range(count):
                    slot, rel = struct.unpack_from('>II', data, start + 12 + i * 8)
                    assert 12 + count * 8 <= rel and rel + 8 <= blobsize
                    tag, length2 = struct.unpack_from('>II', data, start + rel)
                    assert length2 >= 8 and rel + length2 <= blobsize
                    if slot == 5:
                        assert tag == 0xfade7171
                        value = plistlib.loads(data[start+rel+8:start+rel+length2])
                        assert isinstance(value, dict)
            cursor += length
        assert cursor == end
        values.append(value)
    assert all(v == values[0] for v in values), 'different entitlements across slices'
    return values[0]

def sign_app(app, entitlement_file):
    app = app.resolve()
    main_info = plistlib.loads((app / 'Info.plist').read_bytes())
    main = app / main_info['CFBundleExecutable']
    required = plistlib.loads(entitlement_file.read_bytes())
    assert main.is_file() and isinstance(required, dict)
    binaries = {}
    for p in app.rglob('*'):
        if p.is_symlink() or not p.is_file():
            continue
        with p.open('rb') as stream:
            magic = stream.read(4)
        if magic in MAGICS:
            binaries[p] = entitlements(p.read_bytes())
    assert main in binaries
    binaries[main] = required
    bundles = {}
    for p in [app] + list(app.rglob('*.framework')) + list(app.rglob('*.appex')) + list(app.rglob('*.app')):
        info = plistlib.loads((p / 'Info.plist').read_bytes())
        binary = p / info['CFBundleExecutable']
        assert binary in binaries, str(binary)
        bundles[p] = binary
    bundle_binaries = set(bundles.values())
    targets = [(p, p) for p in binaries if p not in bundle_binaries]
    targets += list(bundles.items())
    targets.sort(key=lambda pair: len(pair[0].parts), reverse=True)
    with tempfile.TemporaryDirectory(prefix='rose-sign-') as td:
        for i, (target, binary) in enumerate(targets):
            cmd = ['/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none']
            wanted = binaries[binary]
            if wanted:
                ep = Path(td) / f'{i}.plist'
                ep.write_bytes(plistlib.dumps(wanted))
                cmd += ['--entitlements', str(ep), '--generate-entitlement-der']
            subprocess.run(cmd + [str(target)], check=True)
            assert entitlements(binary.read_bytes()) == wanted, str(binary)
    for target, binary in targets:
        subprocess.run(['/usr/bin/codesign', '--verify', '--strict', '--all-architectures', str(target)], check=True)
    print('Signed and verified', len(binaries), 'Mach-O files;', len(bundles), 'bundles; original entitlements preserved')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('entitlements', type=Path)
    args = parser.parse_args()
    sign_app(args.app, args.entitlements)
