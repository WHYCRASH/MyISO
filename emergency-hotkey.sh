#!/usr/bin/env bash
# /usr/local/bin/emergency-hotkey.sh
# Local emergency wipe trigger — bound to a keyboard shortcut.
# Executes sanitize.sh via passwordless sudo (see sudoers drop-in).
set -euo pipefail
exec sudo /usr/local/sbin/sanitize.sh
