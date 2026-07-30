#!/usr/bin/env python3
"""Give every non-cosmetic form its own ``evolutionChain``.

PokeAPI's evolution chain is species-level.  喵喵 lists 猫老大 and 喵头目 as
siblings with no hint that the split is regional; 卡蒂狗 lists a single 风速狗
even though the Hisuian form becomes the Hisuian Arcanine.  Bundles up to v12
copied that chain onto the species only, so the detail page rendered an empty
evolution card for every regional form.

This module runs as a post-pass over a staged ``details/`` tree — no network,
no PokeAPI calls — and writes, for each form:

* forms in :data:`FORM_EVOLUTION_TARGETS`: the pruned chain, with each node
  swapped for the matching form of that species (name, sprite, ``formKey``)
  pulled straight out of the target species' own ``details/<id>.json``;
* every other non-cosmetic form (mega, g-max, battle forms): a copy of the
  species chain, so an older app build that reads ``forms[].evolutionChain``
  without falling back to the species chain still shows something.

Cosmetic forms are skipped: they inherit the species' data by definition.

:data:`FORM_EVOLUTION_TARGETS` is mirrored in
``flutter/lib/features/dex/form_evolution_targets.dart`` — the app needs it for
installs still on an older bundle.  ``tools/test_form_evolution_targets.py``
fails if the two drift apart, so edit both or neither.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterable

# form key -> [(child species id, form suffix or None), ...] in display order.
# An empty list is a dead end (default 直冲熊 never becomes 堵拦熊); a form key
# that is absent is not filtered at all (mega / g-max share the species chain).
FORM_EVOLUTION_TARGETS: dict[str, list[tuple[int, str | None]]] = {
    # Alolan lines: same child species, different form of it.
    "rattata": [(20, None)],
    "rattata-alola": [(20, "alola")],
    "sandshrew": [(28, None)],
    "sandshrew-alola": [(28, "alola")],
    "vulpix": [(38, None)],
    "vulpix-alola": [(38, "alola")],
    "diglett": [(51, None)],
    "diglett-alola": [(51, "alola")],
    "geodude": [(75, None)],
    "geodude-alola": [(75, "alola")],
    "graveler": [(76, None)],
    "graveler-alola": [(76, "alola")],
    "grimer": [(89, None)],
    "grimer-alola": [(89, "alola")],
    # 喵喵 is the awkward one: three forms, three different results.
    "meowth": [(53, None)],
    "meowth-gmax": [(53, None)],
    "meowth-alola": [(53, "alola")],
    "meowth-galar": [(863, None)],
    # Galarian lines.
    "ponyta": [(78, None)],
    "ponyta-galar": [(78, "galar")],
    "slowpoke": [(80, None), (199, None)],
    "slowpoke-galar": [(80, "galar"), (199, "galar")],
    "farfetchd": [],
    "farfetchd-galar": [(865, None)],
    "corsola": [],
    "corsola-galar": [(864, None)],
    "zigzagoon": [(264, None)],
    "zigzagoon-galar": [(264, "galar")],
    "linoone": [],
    "linoone-galar": [(862, None)],
    "yamask": [(563, None)],
    "yamask-galar": [(867, None)],
    "darumaka": [(555, None)],
    "darumaka-galar": [(555, "galar-standard")],
    # Hisuian lines.
    "growlithe": [(59, None)],
    "growlithe-hisui": [(59, "hisui")],
    "voltorb": [(101, None)],
    "voltorb-hisui": [(101, "hisui")],
    "qwilfish": [],
    "qwilfish-hisui": [(904, None)],
    "sneasel": [(461, None)],
    "sneasel-hisui": [(903, None)],
    "zorua": [(571, None)],
    "zorua-hisui": [(571, "hisui")],
    "basculin-red-striped": [],
    "basculin-blue-striped": [],
    "basculin-white-striped": [(902, None)],
    # Paldean lines.
    "wooper": [(195, None)],
    "wooper-paldea": [(980, None)],
    # Burmy: the cloak carries over to 结草贵妇, 绅士蛾 ignores it.
    "burmy-plant": [(413, None), (414, None)],
    "burmy-sandy": [(413, "sandy"), (414, None)],
    "burmy-trash": [(413, "trash"), (414, None)],
}

# Node fields the target form overrides; everything else (triggers, id) is the
# species node's and stays put.
_FORM_NODE_FIELDS = ("nameZh", "spriteUrl", "artworkUrl", "localSpritePath")


class DetailStore:
    """Lazy read-only view over a staged ``details/`` directory."""

    def __init__(self, details_dir: Path) -> None:
        self.details_dir = details_dir
        self._cache: dict[int, dict[str, Any] | None] = {}

    def detail(self, species_id: int) -> dict[str, Any] | None:
        if species_id not in self._cache:
            path = self.details_dir / f"{species_id}.json"
            self._cache[species_id] = (
                json.loads(path.read_text(encoding="utf-8"))
                if path.is_file()
                else None
            )
        return self._cache[species_id]

    def form(self, species_id: int, form_key: str) -> dict[str, Any] | None:
        detail = self.detail(species_id)
        for form in (detail or {}).get("forms") or []:
            if form.get("key") == form_key:
                return form
        return None


def species_slug(node: dict[str, Any]) -> str:
    return str(node.get("nameEn", "")).lower()


def root_form_key(root: dict[str, Any], form_key: str) -> str | None:
    """The root species' form key matching ``form_key``.

    The selected form usually sits on the root species (卡蒂狗（洗翠）) but can
    sit further down (风速狗（洗翠）), in which case it maps back onto the root
    by its suffix.  Mirrors ``EvolutionNode._rootFormKey`` in Dart, including
    its blind spot: species whose slug contains a hyphen (``mr-mime-galar``)
    do not map and fall through to the unfiltered species chain.
    """
    slug = species_slug(root)
    if form_key == slug or form_key.startswith(f"{slug}-"):
        return form_key if form_key in FORM_EVOLUTION_TARGETS else None
    for index, char in enumerate(form_key):
        if char != "-":
            continue
        candidate = f"{slug}{form_key[index:]}"
        if candidate in FORM_EVOLUTION_TARGETS:
            return candidate
    return slug if slug in FORM_EVOLUTION_TARGETS else None


def _as_form_node(
    node: dict[str, Any],
    form_key: str,
    store: DetailStore,
    problems: list[str],
    *,
    required: bool,
) -> dict[str, Any]:
    """Copy ``node`` wearing the identity of form ``form_key``.

    ``required`` marks the keys a variant was actually asked for.  A default
    target is allowed to miss: 喵头目 has no forms at all, and 结草贵妇's
    default form key is ``wormadam-plant`` rather than the bare species slug —
    in both cases the species node is already the right node.
    """
    resolved = dict(node)
    form = store.form(node["id"], form_key)
    if form is None:
        if required:
            problems.append(
                f"#{node['id']} has no form '{form_key}' — "
                "chain node left as the species"
            )
        return resolved
    if form.get("isDefault"):
        return resolved
    for field in _FORM_NODE_FIELDS:
        if form.get(field):
            resolved[field] = form[field]
    resolved["formKey"] = form_key
    return resolved


def _resolve(
    node: dict[str, Any],
    form_key: str,
    store: DetailStore,
    problems: list[str],
    *,
    required: bool,
) -> dict[str, Any]:
    resolved = _as_form_node(node, form_key, store, problems, required=required)
    targets = FORM_EVOLUTION_TARGETS.get(form_key)
    if targets is None:
        # Not a divergent form — keep the subtree exactly as the species has it.
        resolved["children"] = [dict(child) for child in node.get("children") or []]
        return resolved

    children: list[dict[str, Any]] = []
    for species_id, suffix in targets:
        for child in node.get("children") or []:
            if child.get("id") != species_id:
                continue
            child_slug = species_slug(child)
            child_key = child_slug if suffix is None else f"{child_slug}-{suffix}"
            children.append(
                _resolve(
                    child, child_key, store, problems, required=suffix is not None
                )
            )
    if len(children) != len(targets):
        problems.append(
            f"'{form_key}' targets {targets} but the chain under #{node['id']} "
            f"only matched {[child['id'] for child in children]}"
        )
    resolved["children"] = children
    return resolved


def chain_for_form(
    chain: dict[str, Any],
    form_key: str,
    store: DetailStore,
    problems: list[str],
) -> dict[str, Any]:
    """The species ``chain`` as it applies to ``form_key``."""
    root_key = root_form_key(chain, form_key)
    if root_key is None:
        return json.loads(json.dumps(chain))
    return _resolve(
        chain,
        root_key,
        store,
        problems,
        required=root_key != species_slug(chain),
    )


def apply_form_evolution_chains(
    details_dir: Path,
    *,
    dry_run: bool = False,
    compact: bool = False,
    species_ids: Iterable[int] | None = None,
) -> tuple[int, list[str]]:
    """Write ``forms[].evolutionChain`` across a staged details tree.

    Returns ``(forms touched, problems)``.  Problems are curation errors — a
    table entry naming a form or a branch that the bundle does not have — and
    are worth failing a build over, since each one is a chain the app will
    render wrong.

    ``compact`` writes ``separators=(",", ":")`` to match the patch scripts'
    on-disk format; the full builder writes indented JSON like ``write_json``.
    """
    store = DetailStore(details_dir)
    paths = (
        sorted(details_dir.glob("*.json"), key=lambda p: int(p.stem))
        if species_ids is None
        else [details_dir / f"{species_id}.json" for species_id in species_ids]
    )
    problems: list[str] = []
    touched = 0
    for path in paths:
        if not path.is_file():
            continue
        detail = json.loads(path.read_text(encoding="utf-8"))
        chain = detail.get("evolutionChain")
        forms = detail.get("forms") or []
        if not chain or not forms:
            continue
        changed = False
        for form in forms:
            if form.get("evolutionChain"):
                continue
            # Cosmetic forms inherit the species' data, so they need no copy —
            # unless the table says this one diverges (Burmy's cloaks are
            # cosmetic to PokeAPI but decide which 结草贵妇 you get).
            if form.get("isCosmetic") and form["key"] not in FORM_EVOLUTION_TARGETS:
                continue
            resolved = chain_for_form(chain, form["key"], store, problems)
            form["evolutionChain"] = resolved
            changed = True
            touched += 1
        if changed and not dry_run:
            dump_args: dict[str, Any] = (
                {"separators": (",", ":")} if compact else {"indent": 2}
            )
            path.write_text(
                json.dumps(detail, ensure_ascii=False, **dump_args),
                encoding="utf-8",
            )
    return touched, problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("details_dir", type=Path, help="staged details/ directory")
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the curated table against the tree without writing",
    )
    args = parser.parse_args()

    touched, problems = apply_form_evolution_chains(
        args.details_dir, dry_run=args.check
    )
    for problem in problems:
        print(f"  warn: {problem}", file=sys.stderr)
    verb = "would gain" if args.check else "gained"
    print(f"{touched} forms {verb} an evolution chain, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
