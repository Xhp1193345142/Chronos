"""Read-only publication readiness report. Never reads or prints secret values."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
config = json.loads((root / 'docs/release/config.json').read_text())
checks = []

def check(label, ready):
    checks.append((label, bool(ready)))

check('Developer identified', config.get('developer'))
check('Free release selected', config.get('monetization') == 'free')
check('Public support URL', config.get('support_url', '').startswith('https://'))
check('Hosted privacy policy URL', str(config.get('privacy_policy_url') or '').startswith('https://'))
check('Android production signing configured', all(os.environ.get(key) for key in (
    'CHRONOS_KEYSTORE_PATH', 'CHRONOS_KEYSTORE_PASSWORD', 'CHRONOS_KEY_ALIAS', 'CHRONOS_KEY_PASSWORD'
)) and Path(os.environ.get('CHRONOS_KEYSTORE_PATH', '/nonexistent')).is_file())
check('Full Xcode available', Path('/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild').is_file())
for key, label in [
    ('ios_real_device_verified', 'iPhone real-device acceptance'),
    ('android_usage_accuracy_verified', 'Android usage totals verified against system'),
    ('android_background_reminders_verified', 'Android background reminder acceptance'),
    ('release_profile_verified', 'Release/profile performance acceptance'),
]:
    check(label, config.get(key) is True)
try:
    branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=root, text=True).strip()
except (OSError, subprocess.CalledProcessError):
    branch = ''
check('Development branch is dev', branch == 'dev')
for label, ready in checks:
    print(f'{"READY" if ready else "PENDING"}: {label}')
print('\nThis reports evidence, not store approval. See docs/release/READINESS.md.')
raise SystemExit(0 if all(ready for _, ready in checks) else 1)
