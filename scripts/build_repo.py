#!/usr/bin/env python3
"""Build a flat Sileo/Zebra APT repository from locally built Theos .deb files."""

import gzip
import hashlib
import io
import shutil
import sys
import tarfile
from datetime import datetime, timezone
from pathlib import Path


def control_fields(deb: Path) -> str:
    """Extract the control stanza directly from a Debian ar archive.

    dpkg-deb --field can fail on some hosts if their tar attempts to chown
    the control files while reading them. This parser never extracts to disk.
    """
    data = deb.read_bytes()
    if not data.startswith(b'!<arch>\n'):
        raise ValueError(f'Not a Debian ar archive: {deb}')

    offset = 8
    while offset < len(data):
        header = data[offset:offset + 60]
        if len(header) != 60 or header[58:60] != b'`\n':
            raise ValueError(f'Malformed Debian ar entry: {deb}')
        member_name = header[:16].decode('ascii').strip().rstrip('/')
        member_size = int(header[48:58].decode('ascii').strip())
        start = offset + 60
        end = start + member_size
        if end > len(data):
            raise ValueError(f'Truncated Debian ar entry: {deb}')
        if member_name.startswith('control.tar'):
            with tarfile.open(fileobj=io.BytesIO(data[start:end]), mode='r:*') as archive:
                for member in archive:
                    if member.name.lstrip('./') == 'control' and member.isfile():
                        extracted = archive.extractfile(member)
                        if extracted is None:
                            break
                        return extracted.read().decode('utf8').strip()
            raise ValueError(f'Missing control file: {deb}')
        offset = end + (member_size % 2)

    raise ValueError(f'Missing control.tar member: {deb}')


def main() -> int:
    if len(sys.argv) != 3:
        print('Usage: build_repo.py packages-directory docs-directory', file=sys.stderr)
        return 2

    package_dir = Path(sys.argv[1])
    root = Path(sys.argv[2])
    debs = sorted(package_dir.glob('*.deb'))
    if not debs:
        print('No .deb files to publish', file=sys.stderr)
        return 1

    target_debs = root / 'debs'
    target_debs.mkdir(parents=True, exist_ok=True)
    records = []
    architectures = set()
    for source in debs:
        target = target_debs / source.name
        shutil.copyfile(source, target)
        data = target.read_bytes()
        package_control = control_fields(target)
        if not package_control.startswith('Package: '):
            raise RuntimeError(f'Invalid Debian package control: {source}')

        arch = next((line.split(': ', 1)[1] for line in package_control.splitlines()
                     if line.startswith('Architecture: ')), None)
        if arch:
            architectures.add(arch)

        records.append('\n'.join((
            package_control,
            f'Filename: ./debs/{source.name}',
            f'Size: {len(data)}',
            f'MD5sum: {hashlib.md5(data).hexdigest()}',
            f'SHA256: {hashlib.sha256(data).hexdigest()}',
        )))

    packages = ('\n\n'.join(records) + '\n\n').encode('utf8')
    (root / 'Packages').write_bytes(packages)
    output = io.BytesIO()
    with gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0) as stream:
        stream.write(packages)
    (root / 'Packages.gz').write_bytes(output.getvalue())

    now = datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S +0000')
    lines = [
        'Origin: HomePodBridge',
        'Label: HomePodBridge',
        'Suite: stable',
        'Codename: ios',
        'Components: main',
        'Version: 0.1.0',
        'Architectures: ' + ' '.join(sorted(architectures)),
        'Description: Experimental HomePod mini 2 compatibility tweak for Dopamine rootless',
        f'Date: {now}',
    ]
    for field, digest in [('MD5Sum', hashlib.md5), ('SHA256', hashlib.sha256)]:
        lines.append(f'{field}:')
        for name in ['Packages', 'Packages.gz']:
            body = (root / name).read_bytes()
            lines.append(f' {digest(body).hexdigest()} {len(body):16d} {name}')
    (root / 'Release').write_text('\n'.join(lines) + '\n', encoding='utf8')
    (root / '.nojekyll').touch()

    (root / 'index.html').write_text('''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>HomePodBridge Sileo Repository</title></head>
<body style="font:16px system-ui;margin:3rem auto;max-width:40rem;padding:0 1rem">
<h1>HomePodBridge</h1><p>Experimental HomePod mini 2 support for iOS 16.1.1 with Dopamine rootless.</p>
<p>Add this exact, case-sensitive URL as a source in Sileo:</p>
<pre>https://soum91.github.io/homepodbridge/</pre>
<p>Use only on the matching device and iOS version. This tweak is experimental and may not complete pairing.</p>
</body></html>
''', encoding='utf8')
    print(f'Published {len(debs)} package(s): {", ".join(p.name for p in debs)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
