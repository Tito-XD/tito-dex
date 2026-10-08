"""Regression tests for release provenance and the signing trust boundary.

Run with python3 -m unittest tools.test_android_release_security -v.
Requires PyYAML and Node.js; no credentials or signing keys are used.
"""
import json
from pathlib import Path
import subprocess
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
BUILD = yaml.safe_load((ROOT / '.github/workflows/android-release-build.yml').read_text())
PUBLISH = yaml.safe_load((ROOT / '.github/workflows/publish-android-release.yml').read_text())
SHA = 'a' * 40


def exercise_gate(workflow, **overrides):
    scenario = dict(ref='refs/heads/main', event='workflow_dispatch', protected=True,
                    tip=SHA, sha=SHA, source=SHA, comparison='identical', approved=True,
                    approval_sha=SHA, approval_event='push', approval_repo='owner/repo', environment=True, reviewers=True,
                    self_review=False, bypass=False, policies=[{'name':'main', 'type':'branch'}])
    scenario.update(overrides)
    script = workflow['jobs']['approve-source']['steps'][0]['with']['script']
    harness = '''
const s = JSON.parse(process.argv[1]);
const context = {repo: {owner: 'owner', repo: 'repo'}, ref:s.ref, eventName:s.event, sha:s.sha};
process.env.SOURCE_SHA = s.source;
let output;
const core = {setOutput: (_, value) => {output=value}};
const github = {paginate: async () => s.policies, rest: {
  repos: {
    listDeploymentBranchPolicies: () => {},
    getEnvironment: async () => {
      if (!s.environment) throw Error('environment missing');
      return {data: {can_admins_bypass:s.bypass,
        deployment_branch_policy:{custom_branch_policies:true},
        protection_rules:s.reviewers ? [{type:'required_reviewers',
          prevent_self_review:!s.self_review, reviewers:[{id:1}]}] : []}};
    },
    getBranch: async () => ({data:{protected:s.protected, commit:{sha:s.tip}}}),
    compareCommits: async args => {
      if (args.base !== s.source || args.head !== s.tip) throw Error('wrong comparison');
      return {data:{status:s.comparison}};
    }
  },
  actions: {listWorkflowRuns: async args => {
    if (args.workflow_id !== 'commit-attribution.yml' || args.status !== 'success')
      throw Error('wrong approval query');
    return {data:{workflow_runs: s.approved ? [{head_sha:s.approval_sha,
      event:s.approval_event, head_repository:{full_name:s.approval_repo}}] : []}};
  }}
}};
(async () => { try { SCRIPT; process.stdout.write(JSON.stringify({ok:true, output})); }
catch(e) { process.stdout.write(JSON.stringify({ok:false, error:e.message})); } })();
'''.replace('SCRIPT', script)
    result = subprocess.run(['node', '-e', harness, json.dumps(scenario)],
                            check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


class ReleaseSecurityTests(unittest.TestCase):
    def test_approved_main_passes(self):
        for workflow in [BUILD, PUBLISH]:
            result = exercise_gate(workflow)
            self.assertTrue(result['ok'], result)
            self.assertEqual(result['output'], SHA)

    def test_unapproved_dispatch_rejected_before_environment(self):
        for workflow in [BUILD, PUBLISH]:
            for scenario in [dict(ref='refs/heads/attack'), dict(ref='refs/tags/main'),
                             dict(event='pull_request'), dict(protected=False),
                             dict(approved=False), dict(approval_sha='b'*40),
                             dict(approval_event='pull_request'), dict(approval_repo='attacker/repo')]:
                with self.subTest(scenario=scenario):
                    self.assertFalse(exercise_gate(workflow, **scenario)['ok'])
            gate = workflow['jobs']['approve-source']
            self.assertNotIn('environment', gate)
            self.assertNotIn('checkout', json.dumps(gate))

    def test_missing_or_unsafe_environment_fails_closed(self):
        for workflow in [BUILD, PUBLISH]:
            for scenario in [dict(environment=False), dict(reviewers=False),
                             dict(self_review=True), dict(bypass=True),
                             dict(policies=[]), dict(policies=[{'name':'*', 'type':'branch'}]),
                             dict(policies=[{'name':'main', 'type':'tag'}]),
                             dict(policies=[{'name':'main', 'type':'branch'},
                                            {'name':'attack', 'type':'branch'}])]:
                with self.subTest(scenario=scenario):
                    self.assertFalse(exercise_gate(workflow, **scenario)['ok'])

    def test_build_rejects_stale_main_tip(self):
        self.assertFalse(exercise_gate(BUILD, tip='b'*40)['ok'])

    def test_publisher_requires_full_sha_and_main_ancestry(self):
        for source in ['main', 'a'*7, '../branch']:
            self.assertFalse(exercise_gate(PUBLISH, source=source)['ok'])
        for status in ['behind', 'diverged']:
            self.assertFalse(exercise_gate(PUBLISH, comparison=status)['ok'])
        self.assertTrue(exercise_gate(PUBLISH, comparison='ahead')['ok'])

    def test_repository_code_never_receives_raw_signing_material(self):
        for name, job in BUILD['jobs'].items():
            if name != 'sign':
                text = json.dumps(job)
                self.assertNotIn('secrets.ANDROID_', text)
                self.assertNotIn('base64 --decode', text)
        signer = BUILD['jobs']['sign']
        text = json.dumps(signer)
        for forbidden in ['actions/checkout', 'flutter-action', 'setup-gradle',
                          'actions/cache', 'key.properties', 'verify_release_apk.sh']:
            self.assertNotIn(forbidden, text)
        self.assertEqual(signer['environment'], 'android-release')
        self.assertEqual(set(signer['needs']), {'approve-source', 'validate', 'build', 'build-extension'})
        download = signer['steps'][0]['with']
        self.assertEqual(download['name'], 'unsigned-${{ matrix.artifact }}')
        self.assertNotIn('run-id', download)  # Download is confined to the current run.
        sign = next(step['run'] for step in signer['steps'] if 'run' in step)
        self.assertIn('trap', sign)
        self.assertIn('env:ANDROID_STORE_PASSWORD', sign)
        self.assertIn('EXPECTED_SIGNER_SHA256', sign)

    def test_every_checkout_is_immutable_and_has_no_persistent_token(self):
        for workflow in [BUILD, PUBLISH]:
            for job in workflow['jobs'].values():
                for step in job['steps']:
                    if step.get('uses', '').startswith('actions/checkout@'):
                        self.assertEqual(step['with']['ref'], '${{ needs.approve-source.outputs.source_sha }}')
                        self.assertFalse(step['with']['persist-credentials'])

    def test_publisher_binds_artifacts_to_workflow_identity(self):
        job = PUBLISH['jobs']['verify-and-draft']
        self.assertEqual(job['needs'], 'approve-source')
        script = next(step['run'] for step in job['steps'] if step['name'].startswith('Verify build run'))
        for field in ['.workflow_id', '.path', '.head_branch', '.head_repository.full_name',
                      '.head_sha', '.event', '.conclusion']:
            self.assertIn(field, script)
        self.assertIn('actions/workflows/android-release-build.yml', script)

    def test_shell_steps_parse(self):
        for workflow in [BUILD, PUBLISH]:
            for job in workflow['jobs'].values():
                for step in job['steps']:
                    if 'run' in step:
                        result = subprocess.run(['bash', '-n'], input=step['run'],
                                                text=True, capture_output=True)
                        self.assertEqual(result.returncode, 0, (step['name'], result.stderr))


if __name__ == '__main__':
    unittest.main()
