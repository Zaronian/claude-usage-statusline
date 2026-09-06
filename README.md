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

The script just reads that. No auth, no polling, no transcript parsing, no third-party services — the numbers are the same server-side meters `/usage` shows.

## Status JSON on disk (optional, for agent sessions)

Every run also writes the raw stdin JSON to `~/.claude/usage-data/sessions/<session_id>.json` and `~/.claude/usage-data/latest.json`. An agent session (Claude Code's Bash tool exports `CLAUDE_CODE_SESSION_ID`) can read its own context fill and the account rate-limit meters at checkpoints, e.g.

```bash
jq '{ctx: .context_window.used_percentage, h5: .rate_limits.five_hour.used_percentage, wk: .rate_limits.seven_day.used_percentage}' \
  ~/.claude/usage-data/sessions/$CLAUDE_CODE_SESSION_ID.json
```

To keep the file fresh while a session idles (waiting on subagents), add `"refreshInterval": 30` to the `statusLine` block in `~/.claude/settings.json`. Delete `~/.claude/usage-data/` at any time; nothing depends on it.

## Caveats

- The two meters are your **account-wide** limits (all models combined). Model-specific weekly caps exist server-side but aren't exposed to statusline scripts — run `/usage` for the complete picture.
- If `rate_limits` is absent (e.g., direct API-key billing), the limits section simply doesn't render; everything else still works.
- The `$` figure is Claude Code's estimated API-equivalent cost, not what a subscription actually bills.

## Uninstall

```bash
rm ~/.claude/statusline.sh
```

Then remove the `statusLine` block from `~/.claude/settings.json` (or restore the `settings.json.backup-*` the installer created).

## License

MIT
