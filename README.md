# Claude Code Usage Statusline

A status line for [Claude Code](https://claude.com/claude-code) (terminal or the VS Code extension) that shows your **usage limits** — not just your context window — so you see a rate limit coming before you hit the wall.

```
[Fable 5] 📁 my-project | 🌿 main
█████░░░░░ 58% | $4.12 | ⏱️ 42m 10s | 5h:34% ↻ 4:00pm   wk:91% ↻ Fri 7:00am
```

| Segment | Meaning |
|---|---|
| `█████░░░░░ 58%` | Context-window usage for the current conversation (green → yellow at 70% → red at 90%) |
| `$4.12` | Estimated API-equivalent cost of the session |
| `⏱️ 42m 10s` | Session duration |
| `5h:34% ↻ 4:00pm` | Your account's **5-hour rolling usage limit**, with local reset time |
| `wk:91% ↻ Fri 7:00am` | Your **weekly usage limit**, with reset day and time |

The limit meters use the same yellow-at-70% / red-at-90% thresholds. Why it matters: subagent-heavy work (agent teams, background workflows, deep research) burns account limits fast while barely moving the visible context bar — these two meters are how you find out *before* the "you've hit your limit" message.

## Install

```bash
git clone https://github.com/zaronian/claude-usage-statusline.git
cd claude-usage-statusline
./install.sh
```

The installer:
- copies `statusline.sh` to `~/.claude/statusline.sh`
- adds the `statusLine` entry to `~/.claude/settings.json` without touching your other settings
- backs up anything it replaces, and **refuses to overwrite** a different statusline you've already configured

Takes effect on the next statusline refresh — no restart needed.

## Requirements

- **macOS** (uses BSD `date`; Linux needs two small date-flag tweaks — PRs welcome)
- **jq** — `brew install jq`
- **Claude Code** on a subscription plan (Pro/Max/Team). Recent versions pass `rate_limits` to statusline scripts; if the limits section is blank, update Claude Code (`claude update`).

## How it works

Claude Code pipes a JSON snapshot to your statusline command on every refresh. Recent versions include a `rate_limits` object:

```jsonc
{
  "rate_limits": {
    "five_hour": { "used_percentage": 34.2, "resets_at": "2026-07-22T23:00:00Z" },
    "seven_day": { "used_percentage": 91.7, "resets_at": "2026-07-24T14:00:00Z" }
  }
}
```

The script reads that and prints the bar. No auth, no polling, no transcript parsing, no third-party services — the numbers are the same server-side meters `/usage` shows. Optionally (next section) it also persists the JSON for agent sessions.

## Status JSON on disk (opt-in, for agent sessions)

Create the directory to enable it:

```bash
mkdir -p ~/.claude/usage-data/statusline
```

When that directory exists, every run also writes the stdin JSON, plus a `written_at` epoch field, to `~/.claude/usage-data/statusline/sessions/<session_id>.json` and `.../statusline/latest.json` (private files, atomic writes, non-object input skipped, files older than ~30 days pruned once per session). A Claude Code session can then read its own context fill and the account rate-limit meters:

```bash
jq '{ctx: .context_window.used_percentage, h5: .rate_limits.five_hour.used_percentage, wk: .rate_limits.seven_day.used_percentage, age_s: (now - .written_at)}' \
  ~/.claude/usage-data/statusline/sessions/"${CLAUDE_CODE_SESSION_ID:?}".json
```

Know what you are reading:

- `CLAUDE_CODE_SESSION_ID` is observed in Claude Code's Bash tool, not (yet) in the documented environment variables — guard it as above and fall back to `latest.json` only when you have a single window open.
- The file describes the **main** session. A subagent inherits the parent's id (`CLAUDE_CODE_CHILD_SESSION=1`), so a subagent must not pace on `context_window`; only the account-wide `rate_limits` fields are meaningful there.
- Values are as of the session's most recent API response, not live; `written_at` tells you how old the snapshot is. A `refreshInterval` in `settings.json` re-runs the script but cannot refresh the numbers, so it is not needed for this.
- `latest.json` is whichever session rendered last.
- The file contains the same fields Claude Code sends the status line (model, working directory, transcript path, cost, meters). No credentials, but it is written under your home directory, mode 600.

## Caveats

- The two meters are your **account-wide** limits (all models combined). Model-specific weekly caps exist server-side but aren't exposed to statusline scripts — run `/usage` for the complete picture.
- If `rate_limits` is absent (e.g., direct API-key billing), the limits section simply doesn't render; everything else still works.
- The `$` figure is Claude Code's estimated API-equivalent cost, not what a subscription actually bills.

## Uninstall

```bash
rm ~/.claude/statusline.sh
```

Also `rm -rf ~/.claude/usage-data/statusline` if you enabled the persisted status files (that path is the only one this script writes; other tools keep their own data under `~/.claude/usage-data/`).

Then remove the `statusLine` block from `~/.claude/settings.json` (or restore the `settings.json.backup-*` the installer created).

## License

MIT
