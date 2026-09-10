"""Reject AI Git identities and attribution trailers; retain human credits."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

AI_NAME = re.compile(
    r"^(?:cursor(?: agent|\[bot\])?|claude(?: code| agent|\[bot\]| (?:opus|sonnet|haiku|fable)\b.*)?|"
    r"codex(?: agent|\[bot\])?|openai(?: codex)?|github copilot|copilot(?: agent|\[bot\])?|"
    r"qoder(?: agent|\[bot\])?|devin(?: ai|\[bot\])?)$", re.I
)
AI_EMAILS = {'cursoragent@cursor.com', 'noreply@anthropic.com', 'noreply@openai.com'}
AI_BOT_EMAIL = re.compile(r'^(?:\d+\+)?(?:cursor|claude|codex|copilot|devin)\[bot\]@users\.noreply\.github\.com$', re.I)
CONTACT = re.compile(r'^\s*(.*?)\s*<([^<>]+)>\s*$')


def ai_identity(name, email):
    return bool(AI_NAME.fullmatch(name.strip()) or email.lower() in AI_EMAILS or AI_BOT_EMAIL.fullmatch(email))


def message_issues(message):
    issues = []
    for line in message.splitlines():
        trailer = re.match(r'^\s*co-authored-by\s*:\s*(.*)$', line, re.I)
        if trailer:
            contact = CONTACT.fullmatch(trailer[1])
            if (contact and ai_identity(*contact.groups())) or (not contact and AI_NAME.fullmatch(trailer[1].strip())):
                issues.append('AI co-author trailer')
        if re.match(r'^\s*(?:claude|cursor|codex)-session\s*:', line, re.I):
            issues.append('AI session trailer')
        if re.search(r'(?:made-with\s*:|generated (?:with|by)|co-created with)\s*(?:\[[^\]]*\]\([^)]*\)|.*)', line, re.I):
            if re.search(r'\b(?:claude|cursor|codex|copilot|qoder|devin|openai)\b', line, re.I):
                issues.append('AI generation attribution')
    return issues


def commit_issues(name, email, committer, committer_email, message):
    issues = message_issues(message)
    if ai_identity(name, email):
        issues.append('AI author identity')
    if ai_identity(committer, committer_email):
        issues.append('AI committer identity')
    return issues


def git(*args):
    return subprocess.check_output(['git', *args]).decode('utf-8', errors='replace')


def check_revision(revision):
    # Walk the entire branch so merging an old pre-cleanup branch cannot restore AI authors.
    parts = git('log', '--format=%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x00', revision, '--').split('\0')
    failures = []
    count = 0
    for offset in range(0, len(parts) - 6, 6):
        sha, name, email, committer, committer_email, message = parts[offset:offset + 6]
        # Git separates formatted records with a newline after the final NUL.
        count += 1
        issues = commit_issues(name, email, committer, committer_email, message)
        if issues:
            failures.append(f'{sha.strip()[:12]}: {", ".join(issues)}')
    return count, failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--rev')
    mode.add_argument('--message', type=Path)
    mode.add_argument('--pre-push', action='store_true')
    args = parser.parse_args()
    if args.message:
        issues = message_issues(args.message.read_text(encoding='utf-8-sig'))
        for variable in ['GIT_AUTHOR_IDENT', 'GIT_COMMITTER_IDENT']:
            match = re.match(r'(.*?) <([^>]+)> ', git('var', variable))
            if match and ai_identity(*match.groups()):
                issues.append(f'AI {variable.lower()}')
        revisions = []
    elif args.pre_push:
        revisions = set()
        for line in sys.stdin:
            local_ref, local_sha, remote_ref, _ = line.split()
            if remote_ref.startswith('refs/heads/') and set(local_sha) != {'0'}:
                revisions.add(local_sha)
        issues = []
    else:
        revisions, issues = [args.rev], []
    total = 0
    for revision in revisions:
        count, found = check_revision(revision)
        total += count
        issues.extend(found)
    if issues:
        print('Commit attribution rejected. Use the responsible human identity; preserve real human co-authors.', file=sys.stderr)
        print('\n'.join(issues[:15]), file=sys.stderr)
        if len(issues) > 15:
            print(f'... and {len(issues) - 15} more affected commits.', file=sys.stderr)
        return 1
    print(f'Commit attribution passed ({total} commits checked).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
