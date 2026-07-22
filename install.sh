#!/bin/bash
# Installs the Claude Code usage statusline (context bar + cost + 5-hour/weekly limit meters).
# Safe to re-run. Backs up anything it touches. macOS only.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
DEST="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"
STAMP=$(date +%Y%m%d-%H%M%S)

command -v jq >/dev/null || { echo "jq is required: brew install jq"; exit 1; }
[ -f "$SRC" ] || { echo "statusline.sh not found next to installer"; exit 1; }

mkdir -p "$HOME/.claude"

# Install the script (back up any existing one first)
if [ -f "$DEST" ] && ! cmp -s "$SRC" "$DEST"; then
  cp "$DEST" "$DEST.backup-$STAMP"
  echo "Backed up existing statusline to $DEST.backup-$STAMP"
fi
cp "$SRC" "$DEST" && chmod +x "$DEST"
echo "Installed $DEST"

# Wire it into settings.json without clobbering other settings
if [ -f "$SETTINGS" ]; then
  CURRENT=$(jq -r '.statusLine.command // empty' "$SETTINGS")
  if [ "$CURRENT" = "~/.claude/statusline.sh" ] || [ "$CURRENT" = "$DEST" ]; then
    echo "settings.json already points at the statusline — done."
    exit 0
  fi
  if [ -n "$CURRENT" ]; then
    echo "NOTE: settings.json currently uses a different statusline: $CURRENT"
    echo "Not overwriting it. To switch, set statusLine.command to ~/.claude/statusline.sh manually."
    exit 0
  fi
  cp "$SETTINGS" "$SETTINGS.backup-$STAMP"
  jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh"}' "$SETTINGS" > "$SETTINGS.tmp" \
    && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "Added statusLine to settings.json (backup at $SETTINGS.backup-$STAMP)"
else
  printf '{\n  "statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}\n}\n' > "$SETTINGS"
  echo "Created $SETTINGS with statusLine config"
fi

echo "Done — the statusline appears on the next Claude Code refresh (no restart needed)."
