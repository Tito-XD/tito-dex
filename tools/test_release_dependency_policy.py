"""Regression guard for mutable dependencies crossing release credential boundaries."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / '.github/workflows'


def jobs(text):
    return dict((m[1], m[2]) for m in re.finditer(
        r'^  ([\w-]+):\n(.*?)(?=^  [\w-]+:\n|\Z)', text.split('jobs:\n', 1)[1], re.M | re.S))


def assert_pins(text):
    for ref in re.findall(r'uses:\s*([^\s#]+)', text):
        if not re.fullmatch(r'[\w/-]+@[a-f0-9]{40}', ref):
            raise ValueError('Mutable action reference: ' + ref)


def assert_offline_runtime(job):
    if re.search(r'\bnpm (?:ci|install)\b', job):
        raise ValueError('Credential job installs npm dependencies')
    for command in re.findall(r'([^\n]*pip install[^\n]*)', job):
        for flag in ['--no-index', '--find-links', '--require-hashes', '--only-binary=:all:']:
            if flag not in command:
                raise ValueError('Credential job lacks ' + flag)


class ReleaseDependencyPolicy(unittest.TestCase):
    def test_all_actions_are_immutable(self):
        for path in WORKFLOWS.glob('*.yml'):
            with self.subTest(workflow=path.name):
                assert_pins(path.read_text())

    def test_policy_rejects_mutable_reference(self):
        with self.assertRaises(ValueError):
            assert_pins('uses: actions/checkout@v6')

    def test_python_lock_covers_exact_direct_dependencies(self):
        lock = (ROOT / 'tools/dex_bundle_requirements.lock').read_text()
        locked = {}
        for line in lock.splitlines():
            if not line or line.startswith('#'):
                continue
            match = re.fullmatch(r'([\w-]+)==([\w.]+) --hash=sha256:([a-f0-9]{64})', line)
            self.assertIsNotNone(match, line)
            locked[match[1].lower().replace('_', '-')] = match[2]
        for line in (ROOT / 'tools/dex_bundle_requirements.txt').read_text().splitlines():
            if not line or line.startswith('#'):
                continue
            name, version = line.split('==')
            self.assertEqual(locked[name.lower().replace('_', '-')], version)

    def test_android_signing_is_isolated(self):
        android = jobs((WORKFLOWS / 'android-release-build.yml').read_text())
        for name in ['validate', 'build', 'build-extension']:
            self.assertNotIn('secrets.ANDROID_', android[name])
        sign = android['sign']
        self.assertIn('environment: android-signing', sign)
        self.assertIn('needs: [build, build-extension]', sign)
        self.assertIn('name: unsigned-${{ matrix.variant }}', sign)
        self.assertNotRegex(sign, r'flutter-action|setup-gradle|flutter build|\bgradle\b|\bnpm\b|\bpip\b')
        self.assertIn('apksigner" verify', sign)
        self.assertIn("trap 'rm -f", sign)
        # Publish keeps matching only the final signed artifacts.
        self.assertIn('pattern: TitoDex-*', (WORKFLOWS / 'publish-android-release.yml').read_text())

    def test_cdn_credentials_use_only_promoted_runtime(self):
        release = jobs((WORKFLOWS / 'release-dex-bundle-v20.yml').read_text())
        prepare = release['prepare-runtime']
        self.assertNotIn('secrets.', prepare)
        self.assertIn('pip download --require-hashes --only-binary=:all:', prepare)
        self.assertIn('npm ci --ignore-scripts', prepare)
        for name in ['upload-v5-objects', 'publish-root-manifest']:
            job = release[name]
            assert_offline_runtime(job)
            self.assertIn('prepare-runtime', job)
            self.assertIn('name: dex-release-runtime', job)
            self.assertIn('environment: dex-production', job)

    def test_release_gate_expects_disabled_rollback_to_fail(self):
        release = jobs((WORKFLOWS / 'release-dex-bundle-v20.yml').read_text())
        self.assertIn('if python3 tools/upload_dex_v20_release.py', release['build-and-verify'])
        self.assertIn('grep -q "v19 rollback is disabled"', release['build-and-verify'])

    def test_policy_rejects_online_install_in_credential_job(self):
        for job in ['run: pip install -r requirements.txt', 'run: npm ci']:
            with self.assertRaises(ValueError):
                assert_offline_runtime(job)

    def test_ci_runs_this_policy(self):
        self.assertIn('python3 tools/test_release_dependency_policy.py',
                      (WORKFLOWS / 'flutter-ci.yml').read_text())


if __name__ == '__main__':
    unittest.main()
