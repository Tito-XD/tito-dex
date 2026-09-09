"""Prepare host-only structured query tests from an existing release APK.

No download or publication. Extracts only fixed JSON resource paths into the
Worker's ignored .wrangler/structured-audit directory. Requires tar with zstd.
"""
import argparse
import hashlib
import pathlib
import re
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=pathlib.Path)
    parser.add_argument("--sha256", help="Optional expected APK digest")
    args = parser.parse_args()
    digest = hashlib.sha256(args.apk.read_bytes()).hexdigest()
    if args.sha256 and digest.lower() != args.sha256.lower():
        raise SystemExit("APK checksum mismatch")
    root = pathlib.Path(__file__).resolve().parent.parent
    output = root / "cloudflare/journey-assistant/.wrangler/structured-audit"
    output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.apk) as apk:
        archive = apk.read("assets/flutter_assets/assets/dex/bundle.tar.zst")
    names = subprocess.run(["tar", "-tf", "-"], input=archive, capture_output=True, check=True).stdout.decode().splitlines()
    fixed = {
        "dex_catalog.json", "types.json", "natures.json", "egg_groups.json",
        "weather.json", "terrains.json", "status_conditions.json",
        "location_index.json", "items.json", "moves.json",
        "details/155.json", "details/156.json", "details/157.json",
    }
    selected = [name for name in names if name in fixed or re.fullmatch(r"gameplay/species/[1-9]\d{0,3}\.json", name)]
    if not fixed.issubset(selected):
        raise SystemExit("APK does not contain all required structured resources")
    subprocess.run(["tar", "-xf", "-", "-C", str(output), *selected], input=archive, capture_output=True, check=True)
    print(f"Prepared {len(selected)} JSON resources. APK SHA256: {digest}")


if __name__ == "__main__":
    main()
