#!/usr/bin/env python3
"""Empaqueta el sitio listo para desplegar y el proyecto Godot fuente."""
import hashlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)

README = ROOT / 'README.md'
DOCS = ROOT / 'docs'

print('Empaquetando portafolio…')
portfolio = DIST / 'keiber-urbila-portfolio.zip'
with zipfile.ZipFile(portfolio, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for path in sorted((ROOT / 'site').rglob('*')):
        if path.is_file():
            z.write(path, path.relative_to(ROOT / 'site').as_posix())
    z.write(README, 'README.md')
    for path in sorted(DOCS.glob('*.png')):
        z.write(path, path.relative_to(ROOT).as_posix())
print(f'  {portfolio} ({portfolio.stat().st_size/1024/1024:.1f} MB)')

print('Empaquetando fuente Godot…')
source = DIST / 'pochland-godot-source.zip'
include_dirs = ['experience', 'tools', 'raw-assets']
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    z.write(README, 'README.md')
    for path in sorted(DOCS.glob('*.png')):
        z.write(path, path.relative_to(ROOT).as_posix())
    for dirname in include_dirs:
        base = ROOT / dirname
        for path in sorted(base.rglob('*')):
            if not path.is_file():
                continue
            rel = path.relative_to(ROOT)
            if '.godot/' in rel.as_posix() or '__pycache__' in rel.parts or path.name.endswith('.pyc'):
                continue
            z.write(path, rel.as_posix())
print(f'  {source} ({source.stat().st_size/1024/1024:.1f} MB)')

sums = []
for p in [portfolio, source]:
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    sums.append(f'{h}  {p.name}')
(DIST / 'SHA256SUMS.txt').write_text('\n'.join(sums) + '\n')
print('Listo.')
