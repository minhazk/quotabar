#!/bin/bash
# Proves quotabar's `claude` isolation on the installed Claude Code: a canary SessionStart hook, status
# line and MCP server (user config + project .mcp.json) must FIRE without quotabar's flags (positive
# control) and stay SILENT with them. Uses a throwaway CLAUDE_CONFIG_DIR — your ~/.claude is not touched.
# Costs nothing: `/usage` makes no model call.
set -euo pipefail
command -v claude >/dev/null || { echo "claude not installed — skipped"; exit 0; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/cfg" "$T/cwd" "$T/hits"
printf '#!/bin/bash\ntouch "%s/hits/$1-$$"\n' "$T" > "$T/canary.sh"; chmod +x "$T/canary.sh"
printf '#!/bin/bash\ntouch "%s/hits/mcp-$$"\nsleep 2\n' "$T" > "$T/mcp.sh"; chmod +x "$T/mcp.sh"
cat > "$T/cfg/settings.json" <<J
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"$T/canary.sh sessionstart"}]}],
 "Stop":[{"hooks":[{"type":"command","command":"$T/canary.sh stop"}]}]},
 "statusLine":{"type":"command","command":"$T/canary.sh statusline"}}
J
printf '{"mcpServers":{"canary":{"type":"stdio","command":"%s/mcp.sh","args":[]}}}\n' "$T" > "$T/cfg/.claude.json"
cp "$T/cfg/.claude.json" "$T/cwd/.mcp.json"
cd "$T/cwd"

CLAUDE_CONFIG_DIR="$T/cfg" claude -p /usage --output-format json --max-turns 1 >/dev/null 2>&1 || true
sleep 3
fired=$(ls "$T/hits" | wc -l | tr -d ' ')
[[ "$fired" -gt 0 ]] || { echo "FAIL: positive control — canaries did not fire without isolation; test is blind"; exit 1; }
echo "positive control: $fired canary hit(s) without isolation"
rm -f "$T"/hits/*; rm -rf "$T/cfg/projects"

# Exactly the flags in Sources/QuotaBar/Fetchers.swift (claudeIsolation).
CLAUDE_CONFIG_DIR="$T/cfg" claude -p /usage --output-format json --max-turns 1 --restricted --strict-mcp-config \
  --no-session-persistence --settings '{"disableAllHooks":true,"language":"English"}' >/dev/null 2>&1 || true
CLAUDE_CONFIG_DIR="$T/cfg" claude auth status --json >/dev/null 2>&1 || true
sleep 3
if [[ -n "$(ls "$T/hits")" ]]; then echo "FAIL: canaries fired under isolation: $(ls "$T/hits")"; exit 1; fi
[[ -z "$(find "$T/cfg" -name '*.jsonl' 2>/dev/null)" ]] || { echo "FAIL: a session transcript was saved"; exit 1; }
echo "PASS: no hook, status line or MCP server ran, no transcript saved ($(claude --version 2>/dev/null))"
