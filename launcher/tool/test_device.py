#!/usr/bin/env python3
"""Run device integration tests without losing the user's launcher preferences."""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.tito.titodex.launcher'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('serial', help='ADB serial of the test device')
    args = parser.parse_args()
    os.chdir(ROOT)
    os.umask(0o077)
    flutter = shutil.which('flutter')
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    adb = shutil.which('adb') or (str(Path(sdk) / 'platform-tools/adb') if sdk else None)
    if not flutter or not adb:
        parser.error('flutter and adb must be on PATH (or set ANDROID_HOME).')
    device = [adb, '-s', args.serial]
    target = 'integration_test/launcher_device_test.dart'
    # -r fails on incompatible signatures instead of deleting user data.
    subprocess.run([flutter, 'build', 'apk', '--debug', '--target', target], check=True)
    subprocess.run(device + ['install', '-r', 'build/app/outputs/flutter-apk/app-debug.apk'], check=True)
    subprocess.run(device + ['shell', 'am', 'force-stop', PACKAGE], check=True)
    subprocess.run(device + ['shell', 'run-as', PACKAGE, 'mkdir', '-p', 'shared_prefs', 'files'], check=True)
    backup = ROOT / 'build/validation' / ('device-backup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '.tar')
    backup.parent.mkdir(parents=True, exist_ok=True)
    with backup.open('wb') as out:
        subprocess.run(device + ['exec-out', 'run-as', PACKAGE, 'tar', 'cf', '-', 'shared_prefs', 'files'], stdout=out, check=True)
    backup.chmod(0o600)
    print(f'Private settings and wallpaper backup: {backup}', flush=True)
    subprocess.run(device + ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'], check=True)
    subprocess.run(device + ['shell', 'wm', 'dismiss-keyguard'], check=True)
    try:
        test = subprocess.run([flutter, 'test', target, '-d', args.serial, '--no-uninstall', '--reporter', 'expanded'])
    finally:
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
    return test.returncode


if __name__ == '__main__':
    sys.exit(main())
