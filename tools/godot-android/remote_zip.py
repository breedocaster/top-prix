#!/usr/bin/env python3
"""Extract selected members from a remote ZIP via HTTP range requests.
usage: remote_zip.py URL DEST_DIR NAME_SUBSTR [NAME_SUBSTR ...]   (no substrings = list)"""
import sys, os, struct, zlib, ssl, urllib.request
url, dest, wants = sys.argv[1], sys.argv[2], sys.argv[3:]
ca = os.path.expanduser('~/.ccr/ca-bundle.crt')
ctx = ssl.create_default_context(cafile=ca if os.path.exists(ca) else None)
op = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))
def get(a, b=None):
    r = urllib.request.Request(url, headers={'Range': f'bytes={a}-' if b is None else f'bytes={a}-{b}', 'User-Agent': 'remote-zip'})
    with op.open(r, timeout=300) as f: return f.read()
head = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'remote-zip'})
size = int(op.open(head, timeout=60).headers['Content-Length'])
tail = get(max(0, size - 70000))
i = tail.rfind(b'PK\x05\x06')
cd_n, cd_size, cd_off = struct.unpack('<HII', tail[i+10:i+20])
if cd_off == 0xFFFFFFFF or cd_n == 0xFFFF:  # zip64
    j = tail.rfind(b'PK\x06\x07'); z64 = struct.unpack('<Q', tail[j+8:j+16])[0]
    rec = get(z64, z64 + 56); cd_n, cd_size, cd_off = struct.unpack('<QQQ', rec[32:56])
cd = get(cd_off, cd_off + cd_size - 1)
p = 0; ents = []
while p < len(cd) and cd[p:p+4] == b'PK\x01\x02':
    meth, = struct.unpack('<H', cd[p+10:p+12]); csz, usz = struct.unpack('<II', cd[p+20:p+28])
    nl, xl, cl = struct.unpack('<HHH', cd[p+28:p+34]); off, = struct.unpack('<I', cd[p+42:p+46])
    name = cd[p+46:p+46+nl].decode(); x = cd[p+46+nl:p+46+nl+xl]
    if 0xFFFFFFFF in (csz, usz, off):  # zip64 extra
        q = 0
        while q < len(x):
            hid, hl = struct.unpack('<HH', x[q:q+4])
            if hid == 1:
                vals = list(struct.unpack('<' + 'Q' * (hl // 8), x[q+4:q+4+hl])); k = 0
                if usz == 0xFFFFFFFF: usz = vals[k]; k += 1
                if csz == 0xFFFFFFFF: csz = vals[k]; k += 1
                if off == 0xFFFFFFFF: off = vals[k]
            q += 4 + hl
    ents.append((name, meth, csz, usz, off)); p += 46 + nl + xl + cl
if not wants:
    for e in ents: print(f'{e[3]:>12} {e[0]}')
    sys.exit()
os.makedirs(dest, exist_ok=True)
for name, meth, csz, usz, off in ents:
    if not any(w in name for w in wants): continue
    lh = get(off, off + 29); nl, xl = struct.unpack('<HH', lh[26:30])
    data = get(off + 30 + nl + xl, off + 30 + nl + xl + csz - 1)
    if meth == 8: data = zlib.decompress(data, -15)
    out = os.path.join(dest, os.path.basename(name))
    open(out, 'wb').write(data); print('extracted', name, len(data))
