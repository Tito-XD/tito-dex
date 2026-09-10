import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from check_commit_attribution import ai_identity, check_revision, commit_issues, message_issues


class AttributionTests(unittest.TestCase):
    def test_known_agent_identities(self):
        for name, email in [('Cursor Agent', 'cursoragent@cursor.com'), ('Claude Opus 4.8', 'noreply@anthropic.com'),
                            ('Codex', 'noreply@openai.com'), ('Qoder Agent', 'agent@example.com'),
                            ('cursor[bot]', '206951365+cursor[bot]@users.noreply.github.com')]:
            with self.subTest(name=name):
                self.assertTrue(ai_identity(name, email))

    def test_human_and_release_automation_are_preserved(self):
        for name, email in [('Tito', 'titow.xd@outlook.com'), ('Rachel030219', 'person@example.com'),
                            ('Claude Martin', 'claude@example.com'), ('GitHub', 'noreply@github.com'),
                            ('github-actions[bot]', '41898282+github-actions[bot]@users.noreply.github.com')]:
            self.assertFalse(ai_identity(name, email))

    def test_ai_coauthor_rejected_case_insensitively(self):
        self.assertTrue(message_issues('Fix\n\nCO-AUTHORED-BY: Claude Sonnet 4.6 <noreply@anthropic.com>\n'))
        self.assertTrue(message_issues('Fix\nCo-authored-by: Cursor <cursoragent@cursor.com>'))

    def test_human_coauthor_and_normal_discussion_preserved(self):
        self.assertEqual([], message_issues('Fix cursor position\n\nCo-authored-by: Rachel030219 <person@example.com>\n'))
        self.assertEqual([], message_issues('Disable Claude attribution in repository settings'))

    def test_generation_and_session_attribution_rejected(self):
        for text in ['Made-with: Cursor', 'Generated with [Claude Code](https://claude.com/claude-code)',
                     'Claude-Session: https://claude.ai/code/session_example']:
            self.assertTrue(message_issues(text))

    def test_ai_committer_is_rejected_for_human_author(self):
        self.assertIn('AI committer identity', commit_issues('Tito', 'tito@example.com', 'Cursor Agent', 'cursoragent@cursor.com', 'Fix'))

    def test_historical_bot_cannot_hide_between_human_commits(self):
        records = [('a' * 40, 'Tito', 'tito@example.com', 'Tito', 'tito@example.com', 'One'),
                   ('b' * 40, 'Cursor Agent', 'cursoragent@cursor.com', 'Tito', 'tito@example.com', 'Two'),
                   ('c' * 40, 'Tito', 'tito@example.com', 'Tito', 'tito@example.com', 'Three')]
        log = ''.join('\0'.join(record) + '\0\n' for record in records)
        with patch('check_commit_attribution.git', return_value=log):
            count, failures = check_revision('HEAD')
        self.assertEqual(3, count)
        self.assertEqual(['bbbbbbbbbbbb: AI author identity'], failures)

    def test_real_history_walk_checks_ancestors_but_not_unrelated_old_tags(self):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, GIT_AUTHOR_NAME='Tito', GIT_AUTHOR_EMAIL='tito@example.com',
                       GIT_COMMITTER_NAME='Tito', GIT_COMMITTER_EMAIL='tito@example.com')
            def git(*args, data=None, extra=None):
                return subprocess.check_output(['git', '-C', directory, *args], input=data,
                                               env={**env, **(extra or {})}).decode().strip()
            git('init', '-q')
            tree = git('hash-object', '-t', 'tree', '--stdin', '-w', data=b'')
            first = git('commit-tree', tree, '-m', 'First')
            ai = git('commit-tree', tree, '-p', first, '-m', 'Second',
                     extra={'GIT_AUTHOR_NAME': 'Cursor Agent', 'GIT_AUTHOR_EMAIL': 'cursoragent@cursor.com'})
            third = git('commit-tree', tree, '-p', ai, '-m', 'Third')
            git('update-ref', 'refs/heads/main', third)
            with patch('check_commit_attribution.git', side_effect=lambda *args: git(*args)):
                count, failures = check_revision('refs/heads/main')
            self.assertEqual(3, count)
            self.assertEqual(1, len(failures))
            git('update-ref', 'refs/tags/old-release', ai)
            git('update-ref', 'refs/heads/main', first)
            with patch('check_commit_attribution.git', side_effect=lambda *args: git(*args)):
                count, failures = check_revision('refs/heads/main')
            self.assertEqual((1, []), (count, failures))


if __name__ == '__main__':
    unittest.main()
