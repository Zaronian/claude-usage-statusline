#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; DIM='\033[2m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

# Account rate limits (5-hour window + weekly), provided by Claude Code in stdin JSON
FIVE=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
RESET5=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RESETW=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

to_epoch() {  # ISO-8601 UTC string or epoch seconds -> epoch seconds
  local t="$1"
  case "$t" in
    ''|null) return ;;
    *[!0-9]*) date -ju -f '%Y-%m-%dT%H:%M:%S' "$(echo "$t" | cut -c1-19)" +%s 2>/dev/null ;;
    *) echo "$t" ;;
  esac
}
fmt_time() { date -r "$1" '+%l:%M%p' 2>/dev/null | tr -d ' ' | tr 'APM' 'apm'; }
fmt_day_time() {  # time only if today, else "Thu 7:00am"
  local e="$1"
  if [ "$(date -r "$e" '+%Y%j' 2>/dev/null)" = "$(date '+%Y%j')" ]; then fmt_time "$e"
  else echo "$(date -r "$e" '+%a' 2>/dev/null) $(fmt_time "$e")"; fi
}

LIMITS=""
if [ -n "$FIVE" ]; then
  C5=$GREEN; [ "$FIVE" -ge 70 ] && C5=$YELLOW; [ "$FIVE" -ge 90 ] && C5=$RED
  LIMITS=" | ${C5}5h:${FIVE}%${RESET}"
  E5=$(to_epoch "$RESET5")
  [ -n "$E5" ] && LIMITS="$LIMITS ${DIM}↻ $(fmt_time "$E5")${RESET}"
fi
if [ -n "$WEEK" ]; then
  CW=$GREEN; [ "$WEEK" -ge 70 ] && CW=$YELLOW; [ "$WEEK" -ge 90 ] && CW=$RED
  LIMITS="$LIMITS   ${CW}wk:${WEEK}%${RESET}"
  EW=$(to_epoch "$RESETW")
  [ -n "$EW" ] && LIMITS="$LIMITS ${DIM}↻ $(fmt_day_time "$EW")${RESET}"
fi

BRANCH=""
git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git -C "$DIR" branch --show-current 2>/dev/null)"

echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
COST_FMT=$(printf '$%.2f' "$COST")
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s${LIMITS}"
