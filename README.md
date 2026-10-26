# QuotaBar

**How much AI coding allowance you have left, in your macOS menu bar.**

A native Swift/SwiftUI app based on [LimitBar](https://github.com/dancik/limitbar), with two deliberate changes:

- **Claude shows its all-model weekly allowance in the menu bar.** The five-hour session and per-model windows remain in the dropdown.
- **Every displayed percentage and meter means remaining.** A full allowance is **100**, 23% used is **77**, and an exhausted allowance is **0**.

Claude's weekly window is first in the dropdown. Codex keeps its primary (usually five-hour) window; Gemini shows the tightest Gemini bucket; Grok shows weekly credits. All show percent remaining.

## Reading the menu bar

| Display | Meaning |
| --- | --- |
| `100` | Full allowance remaining |
| `77` | 77% remaining |
| `37ʷ` | 37% of the weekly allowance remaining |
| `<1` | Some allowance remains, below 1% |
| `0` | Exhausted |
| Red | 10% or less remains |
| `!` | Another window has 10% or less remaining |
| `—` | Missing, unavailable, or past its reset time; waiting for a new reading |
| Dimmed | Last reading is more than 45 minutes old |

Hover to open the panel. Click to pin it. The panel says **Allowance remaining**, lists reset times and reading ages, and includes Refresh, Launch at Login, and Quit.

If Claude's all-model weekly reading is unavailable, the menu bar shows `—ʷ` rather than substituting its five-hour or per-model limit. Passing a reset time never guesses that the allowance is full.

## Build and run

Requires macOS 14+, Xcode or Command Line Tools with Swift 6+, and the signed-in official CLIs for the services you use. The app is native Swift; pnpm is a pinned task runner with no JavaScript dependencies.

```sh
pnpm install --frozen-lockfile
pnpm test
pnpm build
pnpm start
```

Or use `scripts/build-app.sh build` and `script/build_and_run.sh --verify` directly. The Run action is also configured in `.codex/environments/environment.toml`.

To install the built app in Applications:

```sh
bash install.sh
```

The installer builds this checkout, verifies the signature, preserves any previous QuotaBar bundle under a timestamped backup name, and opens the new app. It does not alter LimitBar, CLI sign-ins, or Claude settings. Enable Launch at Login from the installed app if desired. Releases are ad-hoc signed, not notarized.

You can also manage the installed app's native macOS login item from Terminal:

```sh
/Applications/QuotaBar.app/Contents/MacOS/QuotaBar --enable-login
/Applications/QuotaBar.app/Contents/MacOS/QuotaBar --login-status
```

An enabled registration prints `Launch at login: enabled`. If macOS reports `requiresApproval`, approve QuotaBar in System Settings → General → Login Items; the command does not bypass that approval.

## Usage sources and privacy

QuotaBar retains LimitBar's collectors and process isolation:

- Claude: `claude auth status --json` plus isolated `claude -p /usage`, or the optional status line helper below.
- Codex: rate-limit records in recent local sessions, with the official `codex app-server` rate-limit method as fallback.
- Gemini: Antigravity CLI `agy -p /quota`.
- Grok: Grok Build's billing RPC.

Sign-in stays in the official CLI. QuotaBar does not directly open credential files, cookies, or keychain items. Codex, Gemini, and Grok run under the inherited kernel sandbox; Claude uses its isolation flags to disable hooks, configured MCP servers, and session persistence. CLI commands have deadlines and a restricted environment. Collectors and upstream CLI behavior can change; unreadable data appears as unavailable, never a fabricated allowance.

The app stores only limit percentages, reset times, plan names, and fixed diagnostic strings in `~/Library/Caches/quotabar` (private folder and files). Internally the vendor's original `used` values are retained to avoid double inversion; display values are converted to remaining. No analytics or separate web service.

Paths and preferences are separate from LimitBar: bundle ID `io.github.minhazk.quotabar`, cache `~/Library/Caches/quotabar`. Override a CLI path with, for example:

```sh
defaults write io.github.minhazk.quotabar codexPath /full/path/to/codex
```

### Optional Claude status line

If your Claude Code version sends `rate_limits` in its status-line payload, QuotaBar can read those without launching `/usage`. Merge this into your existing Claude settings only if you want to replace your status line:

```json
"statusLine": {
  "type": "command",
  "command": "/Applications/QuotaBar.app/Contents/MacOS/QuotaBar --statusline"
}
```

Example output: `Claude Opus · 7d 59% left · 5h 77% left`. The helper saves only quota percentages and reset times, not the surrounding payload. QuotaBar does not edit Claude settings automatically.

## Verification

```sh
pnpm test
pnpm build
pnpm test:integration
tests/claude-canary.sh
```

The Swift tests cover full/partial/empty allowance, invalid and expired data, rounding, weekly selection from old caches, missing weekly data, and secondary-limit warnings. Integration tests cover CLI missing/signed-out/untrusted states, the status-line helper, and the inherited sandbox.

`build/QuotaBar.app/Contents/MacOS/QuotaBar --probe` reads live collectors and prints vendor snapshots. This diagnostic JSON retains source `used` percentages; the app displays remaining.

## Attribution and licence

Derived from [dancik/limitbar](https://github.com/dancik/limitbar) at commit `e7a830a60fe678641cca7960209c14087bf1f86a`. Original copyright and MIT licence are retained in [LICENSE](LICENSE). QuotaBar modifications are also MIT licensed. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for icon credits.

Service names and marks belong to their owners. QuotaBar is not affiliated with Anthropic, Google, OpenAI, xAI, or the LimitBar project.
