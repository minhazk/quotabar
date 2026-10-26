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

Sign-in stays in the official CLI. QuotaBar does not directly open credential files, cookies, or keychain items. It does briefly read the tail of a recent Codex session log to select rate-limit records; it does not save the surrounding conversation. Claude's `auth status` answer includes account details, but QuotaBar keeps only the sign-in flag and plan name.

Codex, Gemini, and Grok run under a kernel sandbox restricting executable paths and filesystem access. This still trusts their allowed interpreters, installation trees and own state folders; it is not a universal guarantee that every plugin or hook is blocked. Gemini additionally receives keychain and shared-temp access for its sign-in/helper. Network access remains available to the CLIs. Claude's `/usage` call uses CLI flags intended to disable hooks, configured MCP servers and session persistence, rather than the kernel sandbox. The separate `auth status` command uses the restricted environment and timeout but not those `/usage` flags.

The app keeps projected quota snapshots in `~/Library/Caches/quotabar`: percentages, resets, vendor/state, plan names, window labels, notes, measurement times and fixed diagnostics. The optional status-line helper keeps accepted quota entries and reset values, not the complete input payload. The folder is private and new files use restricted permissions. Internally the vendor's original `used` values are retained; display values are converted to remaining. QuotaBar has no analytics client or separate backend; launched vendor CLIs retain their own network and account behavior.

### Refresh schedule and usage cost

The scheduler checks about every **30 seconds** (with timer tolerance); this is not a network poll every 30 seconds.

| Source | Normal refresh behavior |
| --- | --- |
| Claude | Read the optional local status file frequently. If it is missing or over 20 minutes old, run `/usage` with a normal 20-minute cooldown. |
| Codex | During local activity, check roughly once a minute. Reuse recent session-log quota records where possible; otherwise ask `account/rateLimits/read`. Idle safety interval: 30 minutes. |
| Gemini / Grok | During activity, approximately every 5 minutes. Idle safety interval: 30 minutes. |
| Missing or unsafe CLI | Look for it again after roughly 5 minutes. |

Opening the panel can refresh non-Claude sources whose last poll is older than 90 seconds. Startup, wake and the Refresh button force polling and can bypass normal cooldowns; a fresh Claude status file is still reused. Collection pauses during sleep. This is a policy based on local activity and cached data, not a guaranteed live quota stream.

These are allowance/billing metadata checks, not requests to generate an AI answer. Local file reads use no model tokens. Claude's built-in `/usage` and Codex's rate-limit read are intended to retrieve account metadata; a check of Claude Code 2.1.310 returned zero model turns, zero input/output tokens and zero reported cost. That observation is not a permanent guarantee about future CLI versions or vendor billing. The checks still use some CPU and network resources. See the [Claude status-line documentation](https://code.claude.com/docs/en/statusline) and [Codex app-server protocol](https://github.com/openai/codex/tree/main/codex-rs/app-server) for their data sources.

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
