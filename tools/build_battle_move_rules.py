"""Extract conservative battle metadata from a pinned Pokemon Showdown revision.

No upstream code is executed. Only literal fields and callback presence are read.
Usage: python tools/build_battle_move_rules.py <downloaded-source-directory>
The directory contains revision.txt, LICENSE, data-moves.ts, data-abilities.ts,
and data-mods-gen{4..8}-moves.ts from that revision.
"""
import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1])
root = Path(__file__).resolve().parents[1]
risky = {'basePowerCallback', 'onBasePower', 'onModifyMove', 'onModifyType',
         'onEffectiveness', 'damage', 'damageCallback', 'ohko', 'multihit',
         'overrideOffensiveStat', 'overrideDefensiveStat', 'overrideOffensivePokemon',
         'onTryHit', 'onTry', 'onTryMove', 'beforeTurnCallback', 'isZ', 'isMax',
         'onModifyDamage', 'onDamage', 'onPrepareHit', 'ignoreDefensive',
         'ignoreAbility', 'willCrit', 'breaksProtect', 'selfdestruct'}
flags = ['contact', 'sound', 'punch', 'bite', 'pulse', 'slicing', 'bullet', 'wind']

def blocks(filename):
    text = (source / filename).read_text(encoding='utf-8')
    return dict(re.findall(r'^\t([a-z0-9]+): \{\n(.*?)^\t\},', text, re.M | re.S))

def fields(block):
    return dict(re.findall(r'^\t\t(\w+)(.*)$', block, re.M))

def literal(fields, key, default):
    value = fields.get(key, '').strip().lstrip(':').strip().rstrip(',')
    if re.fullmatch(r'-?\d+', value):
        return int(value)
    if re.fullmatch(r'["\'][^"\']*["\']', value):
        return value[1:-1].lower()
    return default

current = {key: fields(b) for key, b in blocks('data-moves.ts').items()}
versions = {9: current}
for gen in range(8, 3, -1):
    current = {key: dict(value) for key, value in current.items()}
    for key, b in blocks(f'data-mods-gen{gen}-moves.ts').items():
        changes = fields(b)
        if changes.get('inherit', '').strip() != ': true,':
            # Keep identity even in complete historical definitions.
            current[key] = {'num': current.get(key, {}).get('num', ': 0,')}
        current.setdefault(key, {}).update(changes)
    versions[gen] = current

rows = {}
for key, modern in versions[9].items():
    num = literal(modern, 'num', 0)
    if num <= 0 or num >= 1000:
        continue
    history = []
    previous = None
    for gen in range(4, 10):
        f = versions[gen][key]
        mask = sum(1 << i for i, flag in enumerate(flags)
                   if re.search(r'\b' + flag + r': 1\b', f.get('flags', '')))
        if literal(f, 'priority', 0) > 0:
            mask |= 256
        if literal(f, 'target', '') in ('alladjacent', 'alladjacentfoes'):
            mask |= 512
        unsafe = any(k in f and f[k].strip() not in (': null,', ': false,') for k in risky)
        record = [literal(f, 'basePower', 0), literal(f, 'type', ''),
                  literal(f, 'category', ''), mask, unsafe]
        if record != previous:
            history.append([gen, *record])
            previous = record
    rows[num] = history

ability_rows = {}
attack_hooks = {'onBasePower', 'onModifyAtk', 'onModifySpA', 'onModifyMove',
                'onModifyType', 'onModifyDamage', 'onModifyPriority', 'onAnyBasePower',
                'onAnyModifyDamage', 'onAnyTryMove', 'onStart'}
defense_hooks = {'onSourceBasePower', 'onSourceModifyAtk', 'onSourceModifySpA',
                 'onSourceModifyDamage', 'onDamage', 'onTryHit', 'onTryPrimaryHit',
                 'onAnyModifyDamage', 'onAnyTryMove', 'onFoeTryMove', 'onAllyTryHit',
                 'onAnyTryHit', 'onModifyDef', 'onModifySpD', 'onEffectiveness', 'onStart'}
for key, b in blocks('data-abilities.ts').items():
    f = fields(b)
    ability_rows[key] = [bool(attack_hooks & f.keys()), bool(defense_hooks & f.keys())]

target = root / 'flutter/lib/features/companion/battle_rule_data.dart'
text = '// Pokemon Showdown, MIT license; see docs/licenses/pokemon-showdown.txt.\n'
text += '// Source revision: ' + (source / 'revision.txt').read_text().strip() + '\n'
text += '// Rebuild with tools/build_battle_move_rules.py; do not hand-edit.\n'
text += 'const battleMoveRuleData = <int, List<List<Object>>>{\n'
for num, history in sorted(rows.items()):
    text += f'  {num}: {json.dumps(history)},\n'
text += '};\nconst battleAbilityRuleData = <String, List<bool>>{\n'
for key, values in sorted(ability_rows.items()):
    text += f'  "{key}": {json.dumps(values)},\n'
text += '};\n'
target.write_text(text, encoding='utf-8')
license_path = root / 'docs/licenses/pokemon-showdown.txt'
license_path.parent.mkdir(parents=True, exist_ok=True)
license_path.write_bytes((source / 'LICENSE').read_bytes())
print(f'{len(rows)} move histories; {len(ability_rows)} ability classifications')
