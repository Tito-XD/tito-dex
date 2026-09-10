#!/usr/bin/env python3
"""Build the bundled URL index from audited source identities; no network/media.

Paraíso records have verified GIF headers, not full-file animation verification.
The app validates the downloaded animation before adopting any indexed candidate.
ShinyHunters adds only decoded samples with an unambiguous local form binding.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from audit_hd_companion_sources import baseline

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'docs/research/hd-companion-audit-2026-09-10'
OUTPUT = ROOT / 'flutter/assets/data/companion_animation_catalog.json'
SOURCES = {
    'swsh-hd': {'generation': 8, 'labelZh': '剑盾素材集 · Paraíso', 'labelEn': 'Sword/Shield collection · Paraíso'},
    'usum-hd': {'generation': 7, 'labelZh': '究极日月 · Paraíso', 'labelEn': 'Ultra Sun/Moon · Paraíso'},
    'shinyhunters': {'generation': 100, 'labelZh': 'ShinyHunters', 'labelEn': 'ShinyHunters'},
}
# Explicit source guide IDs, not national numbers. Ambiguous cream/ride/tea
# variants remain in the research evidence, not in this runtime index.
SH_BINDINGS = {
    '1': (1, 'bulbasaur'), '162': (162, 'furret'),
    '252': (252, 'treecko'), '493': (493, 'arceus-normal'),
    '649': (649, 'genesect'), '658': (658, 'greninja'),
    '784': (773, 'silvally-normal'), '903': (810, 'grookey'),
    '1024': (58, 'growlithe-hisui'), '1044': (906, 'sprigatito'),
    '867': (201, 'unown-b'), '843': (666, 'vivillon-icy-snow'),
}


def build_catalog():
    targets, _ = baseline()
    identities = {(t['speciesId'], t['formKey']): t for t in targets}
    audit = json.loads((AUDIT / 'hd-companion-coverage.json').read_text(encoding='utf-8'))
    files = {a['url']: a for a in audit['assets']}
    entries = []

    def add(species_id, form_key, source, url, shiny, width, height, size, frames=None):
        identity = identities[(species_id, form_key)]
        color = 'shiny' if shiny else 'normal'
        suffix = hashlib.sha256(url.encode()).hexdigest()[:10]
        entries.append({
            'id': f'{source}:{species_id}:{form_key}:{color}:{suffix}',
            'speciesId': species_id, 'formKey': form_key,
            'nameZh': identity['nameZh'],
            'nameEn': form_key.replace('-', ' ').title() if identity['alternate'] else identity['nameEn'],
            'isDefault': not identity['alternate'], 'source': source,
            'shiny': shiny, 'url': url, 'width': width, 'height': height,
            'sizeBytes': size, 'frameCount': frames,
        })

    for item in audit['mappedAssets']:
        check = files[item['url']]['verification']
        if not check.get('gifHeaderValid'):
            continue
        size = re.search(r'/(\d+)$', check.get('contentRange', ''))
        if not size:
            raise ValueError(f"Missing actual file size: {item['url']}")
        add(item['speciesId'], item['formKey'], item['source'], item['url'],
            item['shiny'], check['width'], check['height'], int(size[1]))

    samples = json.loads((AUDIT / 'expanded-source-samples.json').read_text(encoding='utf-8'))
    for item in samples['shinyHuntersSamples']:
        binding = SH_BINDINGS.get(item['guideUrl'].rsplit('/', 1)[-1])
        if binding is None:
            continue
        assert binding[0] == item['speciesId']
        for asset in item['assets']:
            if asset.get('format') != 'GIF' or asset.get('frames', 0) <= 1:
                continue
            add(*binding, 'shinyhunters', asset['url'], '/shiny/' in asset['url'],
                *asset['dimensions'], asset['bytes'], asset['frames'])
    for asset in samples['furretComparison']:
        if 'shinyhunters.com/' in asset['url']:
            add(162, 'furret', 'shinyhunters', asset['url'], '/shiny/' in asset['url'],
                *asset['dimensions'], asset['bytes'], asset['frames'])
    entries.sort(key=lambda e: (e['speciesId'], e['formKey'], e['source'], e['shiny'], e['id']))
    assert len({e['id'] for e in entries}) == len(entries)
    return {'schemaVersion': 1, 'catalogVersion': '2026-09-10.1',
            'sources': SOURCES, 'entries': entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    raw = json.dumps(build_catalog(), ensure_ascii=False, separators=(',', ':')) + '\n'
    if args.check:
        if OUTPUT.read_text(encoding='utf-8') != raw:
            raise SystemExit('Bundled companion animation catalog is stale')
    else:
        OUTPUT.write_text(raw, encoding='utf-8')
    print(f'{len(json.loads(raw)["entries"])} candidates, {len(raw.encode())} bytes; metadata only')


if __name__ == '__main__':
    main()
