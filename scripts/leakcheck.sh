#!/bin/bash
# Fails if any commit (all history) contains something that identifies a machine or a person: home-folder
# paths, email addresses other than GitHub noreply, or token/key shapes. Runs in CI on every push and
# locally before every push. Generic on purpose — it names no one.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
hit() { echo "LEAK? $1"; fail=1; }

# Every commit: identities, full message, full patch — this script included (its patterns cannot match themselves).
content="$(git log -p --all --format='%H %an <%ae> %cn <%ce>%n%B')"
# Home-folder paths with a real user name (placeholders like /Users/runner, <you> are fine).
grep -E '/Users/[A-Za-z0-9._-]+' <<<"$content" | grep -vE '/Users/(runner|<[a-z]+>|you|USER|example|Shared)\b' >/dev/null && hit "home path (value withheld)" || true
grep -E '/home/[a-z][a-z0-9._-]+' <<<"$content" | grep -vE '/home/(runner|user)\b' >/dev/null && hit "linux home path (value withheld)" || true
# Email addresses: only GitHub noreply and example.com are allowed anywhere, author lines included.
grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' <<<"$content" \
  | grep -vE '@(users\.noreply\.github\.com|example\.com|anthropic\.com)$' >/dev/null && hit "email address (value withheld)" || true
# Token / key shapes.
grep -qE '(sk-[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{10,}|xai-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,})' <<<"$content" && hit "token-shaped string (value withheld)" || true
# Files that must never be committed.
git log --all --name-only --format= | grep -iE '(^|/)(\.env|.*\.db|.*\.sqlite.*|.*cookie.*|.*session.*\.json|.*\.pem|.*\.key|.*\.p12|id_rsa.*|id_ed25519.*|state\.json|claude-status\.json)$' >/dev/null && hit "forbidden file name (value withheld)" || true

[[ $fail -eq 0 ]] && echo "leakcheck: clean" || { echo "leakcheck: FAILED"; exit 1; }
