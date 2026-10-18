#!/usr/bin/env python3
"""Smoke-test a build on a real device without losing the user's launcher preferences.

Backs up shared_prefs + files via run-as, upgrades with `install -r` (never uninstalls), launches the
launcher, checks it stays alive without a fatal exception, then restores the backup and verifies it
file by file. Instrumented tests (connectedAndroidTest) are deliberately not used: they uninstall the app.
"""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.tito.titodex.launcher'
APK = ROOT / 'app/build/outputs/apk/release/app-release.apk'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('serial', help='ADB serial of the test device')
    parser.add_argument('--apk', type=Path, help='install this APK instead of building app-release.apk')
    parser.add_argument('--debug-apk', type=Path, help='same-signer debuggable build used to unlock run-as when a release build is installed')
    parser.add_argument('--keep', action='store_true', help='skip the restore so the new build keeps running on migrated data')
    args = parser.parse_args()
    os.chdir(ROOT)
    os.umask(0o077)
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    adb = shutil.which('adb') or (str(Path(sdk) / 'platform-tools/adb') if sdk else None)
    if not adb:
        parser.error('adb must be on PATH (or set ANDROID_HOME).')
    device = [adb, '-s', args.serial]
    apk = args.apk
    if apk is None:
        subprocess.run(['./gradlew', ':app:assembleRelease', '--console=plain'], check=True)
        apk = APK

    subprocess.run(device + ['shell', 'am', 'force-stop', PACKAGE], check=True)
    if subprocess.run(device + ['shell', 'run-as', PACKAGE, 'true'], capture_output=True).returncode != 0:
        # A release (non-debuggable) install blocks run-as. Replacing it with the same-signer debug build keeps
        # the data directory untouched and makes it readable; the app is not launched before the backup.
        if not args.debug_apk:
            parser.error('installed build is not debuggable; pass --debug-apk app/build/outputs/apk/debug/app-debug.apk')
        subprocess.run(device + ['install', '-r', str(args.debug_apk)], check=True)
        subprocess.run(device + ['shell', 'am', 'force-stop', PACKAGE], check=True)
    subprocess.run(device + ['shell', 'run-as', PACKAGE, 'mkdir', '-p', 'shared_prefs', 'files'], check=True)
    backup = ROOT / 'build/validation' / ('device-backup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '.tar')
    backup.parent.mkdir(parents=True, exist_ok=True)
    with backup.open('wb') as out:
        subprocess.run(device + ['exec-out', 'run-as', PACKAGE, 'tar', 'cf', '-', 'shared_prefs', 'files'], stdout=out, check=True)
    backup.chmod(0o600)
    print(f'Private settings and wallpaper backup: {backup}', flush=True)

    ok = False
    try:
        # -r fails on incompatible signatures instead of deleting user data.
        subprocess.run(device + ['install', '-r', str(apk)], check=True)
        subprocess.run(device + ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'], check=True)
        subprocess.run(device + ['logcat', '-c'], check=True)
        subprocess.run(device + ['shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/.MainActivity'], check=True)
        time.sleep(4)
        pid = subprocess.run(device + ['shell', 'pidof', PACKAGE], capture_output=True, text=True).stdout.strip()
        crash = subprocess.run(device + ['logcat', '-d', '-b', 'crash'], capture_output=True, text=True).stdout
        fatal = PACKAGE in crash
        print(f'pid={pid or "-"} fatal={fatal}', flush=True)
        ok = bool(pid) and not fatal
        if fatal:
            print(crash[-4000:])
    finally:
        if not args.keep:
            subprocess.run(device + ['shell', 'am', 'force-stop', PACKAGE], check=True)
            if subprocess.run(device + ['shell', 'run-as', PACKAGE, 'true'], capture_output=True).returncode != 0:
                if not args.debug_apk:
                    raise RuntimeError(f'Restore needs --debug-apk; backup retained at {backup}')
                subprocess.run(device + ['install', '-r', str(args.debug_apk)], check=True)
                subprocess.run(device + ['shell', 'am', 'force-stop', PACKAGE], check=True)
            with backup.open('rb') as data:
                subprocess.run(device + ['exec-in', 'run-as', PACKAGE, 'tar', 'xf', '-'], stdin=data, check=True)
            with tarfile.open(backup) as archive:
                for member in archive:
                    if member.isfile():
                        expected = archive.extractfile(member).read()
                        actual = subprocess.check_output(device + ['exec-out', 'run-as', PACKAGE, 'cat', member.name])
                        if actual != expected:
                            raise RuntimeError(f'Backup restore verification failed: {member.name}')
            print('Original preferences and wallpaper restored and verified.', flush=True)
            subprocess.run(device + ['install', '-r', str(apk)], check=True)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
