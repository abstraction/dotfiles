#!/bin/bash
# statusline.sh - Resilient and Maximized Telemetry Statusline for Antigravity CLI
# Built with premium 256-color powerline theme & instant system diagnostics

set -euo pipefail
export LC_NUMERIC=C
for arg in "$@"; do
  if [ "$arg" = "--version" ] || [ "$arg" = "-v" ]; then
    echo "Antigravity CLI Statusline v0.2.3"
    exit 0
  fi
  if [ "$arg" = "--legend" ] || [ "$arg" = "-l" ] || [ "$arg" = "legend" ]; then
    echo -e "\033[38;2;120;130;75m\033[1m🚀 Minimal Omarchy Statusline Legend\033[0m"
    echo -e "A high-density, single-line telemetry dashboard. Elements stay hidden until needed."
    echo -e ""
    echo -e "\033[1mLAYOUT:\033[0m"
    echo -e "  [Identity & State]  |  [Context & Tokens]  |  [System & Tasks]  |  [Quotas]"
    echo -e ""
    echo -e "\033[1mICONS & METRICS:\033[0m"
    echo -e "  \033[1m READY /  WORKING\033[0m   Agent state. Changes color when processing or running tools."
    echo -e "  \033[1m Gemini 3.1 Pro\033[0m      Active model."
    echo -e "  \033[1m ~ / main*\033[0m           Current directory and Git branch. Adds * if dirty."
    echo -e "  \033[1m󱍏 11.6%\033[0m               Context window usage. Hits 100% when memory is full."
    echo -e "  \033[1m 121K/45K (+119K/1K)\033[0m Token tracking. Format is Input / Output. Left side is total session usage."
    echo -e "                        Right side (+turn) is tokens consumed during the very last prompt."
    echo -e "  \033[1m 76% 0.79\033[0m            Local machine RAM usage and 1-minute CPU load."
    echo -e "  \033[1m 4  󱙺 0   0\033[0m         Active artifacts, running subagents, and background tasks."
    echo -e "  \033[1m󰦜 host\033[0m                Execution mode. (host = direct local execution)."
    echo -e "  \033[1m5H 42.8% ⌛ 2h 48m\033[0m    5-hour API quota limit and countdown to reset."
    echo -e "  \033[1m7D 2.3% ⌛ 1d 20h\033[0m     Weekly API quota limit and countdown to reset."
    echo -e ""
    echo -e "\033[1mTHEMING:\033[0m"
    echo -e "  Colors are hardcoded to the Omarchy theme palette for maximum speed."
    exit 0
  fi
done
# ─── stdin timeout guard ──────────────────────────────────────────────────────
# The CLI's statusline runner hard-kills this script (~5-10s) if it never
# returns. During auth/OAuth refresh or resume-conversation warm-up, stdin can
# be held open by the runner without being written to or closed, so an
# unbounded `cat` read on stdin hangs until SIGKILL — and enough
# consecutive kills auto-disables the custom statusline. Read stdin with a
# short timeout up front and close it immediately after, so the rest of the
# script never blocks on it.
run_with_timeout() {
  local t="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground "$t" "$@"
  else
    "$@" <&0 &
    local pid=$!
    ( sleep "$t"; kill "$pid" 2>/dev/null || true ) &
    local killer=$!
    wait "$pid" 2>/dev/null
    local res=$?
    kill "$killer" 2>/dev/null || true
    wait "$killer" 2>/dev/null || true
    return $res
  fi
}

INPUT_JSON=$(run_with_timeout 0.25 cat 2>/dev/null || true)
exec 0</dev/null
if [ -z "$INPUT_JSON" ]; then
  INPUT_JSON="{}"
fi

# ─── ANSI Helpers (Standard colors) ───────────────────────────────────────────
R="\033[0m"         # Reset
B="\033[1m"         # Bold
D="\033[2m"         # Dim
I="\033[3m"         # Italic

# Foreground standard colors for classic fallback
FG_BLACK="\033[30m"
FG_RED="\033[31m"
FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_BLUE="\033[34m"
FG_MAGENTA="\033[35m"
FG_CYAN="\033[36m"
FG_WHITE="\033[37m"

FG_GRAY="\033[90m"
FG_BRIGHT_RED="\033[91m"
FG_BRIGHT_GREEN="\033[92m"
FG_BRIGHT_YELLOW="\033[93m"
FG_BRIGHT_BLUE="\033[94m"
FG_BRIGHT_MAGENTA="\033[95m"
FG_BRIGHT_CYAN="\033[96m"
FG_BRIGHT_WHITE="\033[97m"

NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# ─── Parse JSON from stdin (Single jq pass for performance) ──────────────────
{
  read -r STATE
  read -r USED_PCT
  read -r VCS_BRANCH
  read -r VCS_DIRTY
  read -r VCS_TYPE
  read -r VCS_CLIENT
  read -r SANDBOX
  read -r SANDBOX_NET
  read -r ARTIFACTS
  read -r SUBAGENTS
  read -r BG_TASKS
  read -r MODEL_ID
  read -r MODEL_NAME
  read -r COLS
  read -r CWD
  read -r CONV_ID
  read -r PRODUCT
  read -r INPUT_TOKENS
  read -r OUTPUT_TOKENS
  read -r CTX_LIMIT
  read -r CTX_USED
  read -r REM_PCT
  read -r GEMINI_5H
  read -r GEMINI_WK
  read -r TP_5H
  read -r TP_WK
  read -r GEMINI_5H_RESET
  read -r GEMINI_WK_RESET
  read -r TP_5H_RESET
  read -r TP_WK_RESET
  read -r CLI_VERSION
  read -r PLAN_TIER
  read -r USER_EMAIL
  read -r TURN_INPUT_TOKENS
  read -r TURN_OUTPUT_TOKENS
} <<< "$(
  printf '%s' "$INPUT_JSON" | jq -r '
    (.agent_state // "idle"),
    (.context_window.used_percentage // 0),
    (.vcs.branch // ""),
    (.vcs.dirty // false),
    (.vcs.type // ""),
    (.vcs.client // ""),
    (.sandbox.enabled // false),
    (.sandbox.allow_network // false),
    (.artifact_count // 0),
    (if .subagents | type == "array" then (.subagents | length) else 0 end),
    (.task_count // 0),
    (.model.id // ""),
    (.model.display_name // ""),
    (.terminal_width // 80),
    (.cwd // ""),
    (.conversation_id // ""),
    (.product // ""),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (.context_window.context_window_size // 0),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.context_window.remaining_percentage // 100),
    (if .quota["gemini-5h"].remaining_fraction != null then ((.quota["gemini-5h"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["gemini-weekly"].remaining_fraction != null then ((.quota["gemini-weekly"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["3p-5h"].remaining_fraction != null then ((.quota["3p-5h"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["3p-weekly"].remaining_fraction != null then ((.quota["3p-weekly"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (.quota["gemini-5h"].reset_in_seconds // -1),
    (.quota["gemini-weekly"].reset_in_seconds // -1),
    (.quota["3p-5h"].reset_in_seconds // -1),
    (.quota["3p-weekly"].reset_in_seconds // -1),
    (.version // ""),
    (.plan_tier // ""),
    (.email // ""),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0)
  ' 2>/dev/null || printf "idle\n0\n\nfalse\n\n\nfalse\nfalse\n0\n0\n0\n\n\n80\n\n\n\n0\n0\n0\n0\n100\n-1\n-1\n-1\n-1\n-1\n-1\n-1\n-1\n\n\n\n0\n0\n"
)"



# ─── Numeric Payload Sanitization (Defensive against invalid/string JSON values) ──
if ! [[ "$USED_PCT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then USED_PCT=0; fi
if ! [[ "$COLS" =~ ^[0-9]+$ ]]; then COLS=80; fi
if ! [[ "$ARTIFACTS" =~ ^[0-9]+$ ]]; then ARTIFACTS=0; fi
if ! [[ "$SUBAGENTS" =~ ^[0-9]+$ ]]; then SUBAGENTS=0; fi
if ! [[ "$BG_TASKS" =~ ^[0-9]+$ ]]; then BG_TASKS=0; fi
if ! [[ "$INPUT_TOKENS" =~ ^[0-9]+$ ]]; then INPUT_TOKENS=0; fi
if ! [[ "$OUTPUT_TOKENS" =~ ^[0-9]+$ ]]; then OUTPUT_TOKENS=0; fi
if ! [[ "$CTX_LIMIT" =~ ^[0-9]+$ ]]; then CTX_LIMIT=0; fi
if ! [[ "$CTX_USED" =~ ^[0-9]+$ ]]; then CTX_USED=0; fi
if ! [[ "$TURN_INPUT_TOKENS" =~ ^[0-9]+$ ]]; then TURN_INPUT_TOKENS=0; fi
if ! [[ "$TURN_OUTPUT_TOKENS" =~ ^[0-9]+$ ]]; then TURN_OUTPUT_TOKENS=0; fi

if ! [[ "$GEMINI_5H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then GEMINI_5H="-1"; fi
if ! [[ "$GEMINI_WK" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then GEMINI_WK="-1"; fi
if ! [[ "$TP_5H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then TP_5H="-1"; fi
if ! [[ "$TP_WK" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then TP_WK="-1"; fi

if ! [[ "$GEMINI_5H_RESET" =~ ^[0-9]+$ ]]; then GEMINI_5H_RESET="-1"; fi
if ! [[ "$GEMINI_WK_RESET" =~ ^[0-9]+$ ]]; then GEMINI_WK_RESET="-1"; fi
if ! [[ "$TP_5H_RESET" =~ ^[0-9]+$ ]]; then TP_5H_RESET="-1"; fi
if ! [[ "$TP_WK_RESET" =~ ^[0-9]+$ ]]; then TP_WK_RESET="-1"; fi

# ─── Subagent Truth Caching & Countdown Helpers ─────────────────────────────
_SUBAGENT_TRUTH_FILE="/tmp/agy_subagent_truth"
if [ -f "$_SUBAGENT_TRUTH_FILE" ]; then
  _TRUTH_VAL=$(< "$_SUBAGENT_TRUTH_FILE") 2>/dev/null || _TRUTH_VAL=""
  _TRUTH_TIME=$(stat -c "%Y" "$_SUBAGENT_TRUTH_FILE" 2>/dev/null || stat -f "%m" "$_SUBAGENT_TRUTH_FILE" 2>/dev/null || echo "0")
  _TRUTH_TIME=${_TRUTH_TIME:-0}
  _NOW=$(date +%s)
  _AGE=$(( _NOW - _TRUTH_TIME )) 2>/dev/null || _AGE=999
  if [ "$_AGE" -lt 120 ] && [ "$_TRUTH_VAL" = "0" ] && [ "${SUBAGENTS:-0}" -gt 0 ] 2>/dev/null; then
    SUBAGENTS=0
  fi
fi
if [ "${SUBAGENTS:-0}" = "0" ]; then
  echo "0" > "$_SUBAGENT_TRUTH_FILE" 2>/dev/null || true
fi

_tick_countdown() {
  local val="$1"
  local cache_file="$2"
  local now; now=$(date +%s)

  if [ -z "$val" ] || [ "$val" -le 0 ] 2>/dev/null; then
    rm -f "$cache_file" 2>/dev/null || true
    echo "-1"
    return
  fi

  if [ -f "$cache_file" ]; then
    local cached; cached=$(< "$cache_file") 2>/dev/null || cached=""
    if [ -z "$cached" ]; then
      echo "${val}:${now}" > "$cache_file" 2>/dev/null || true
      echo "$val"; return
    fi
    local cached_sec="${cached%%:*}"
    local cached_epoch="${cached#*:}"
    local elapsed=$(( now - cached_epoch ))
    local live=$(( cached_sec - elapsed ))

    local drift=$(( val - live ))
    drift=${drift#-}
    if [ "$drift" -gt 120 ] || [ "$live" -le 0 ]; then
      echo "${val}:${now}" > "$cache_file" 2>/dev/null || true
      echo "$val"
    else
      echo "$live"
    fi
  else
    echo "${val}:${now}" > "$cache_file" 2>/dev/null || true
    echo "$val"
  fi
}

# ─── Parse CLI Arguments & Theme ─────────────────────────────────────────────
USE_CLASSIC_ICONS=false
for arg in "$@"; do
  if [ "$arg" = "--version" ] || [ "$arg" = "-v" ]; then
    echo "Antigravity CLI Statusline v0.2.2"
    exit 0
  fi
  if [ "$arg" = "--compact" ]; then
    COLS=89
  elif [ "$arg" = "--medium" ]; then
    COLS=120
  elif [ "$arg" = "--medium-wide" ]; then
    COLS=150
  elif [ "$arg" = "--classic" ] || [ "$arg" = "--no-nerdfont" ] || [ "$arg" = "--compatibility" ] || [ "$arg" = "-l" ] || [ "$arg" = "--legend" ] || [ "$arg" = "legend" ]; then
    # We parse argument to see if it is legend command
  if [ "$arg" = "--legend" ] || [ "$arg" = "-l" ] || [ "$arg" = "legend" ]; then
    echo -e "\033[38;2;120;130;75m\033[1m🚀 Minimal Omarchy Statusline Legend\033[0m"
    echo -e "A high-density, single-line telemetry dashboard. Elements stay hidden until needed."
    echo -e ""
    echo -e "\033[1mLAYOUT:\033[0m"
    echo -e "  [Identity & State]  |  [Context & Tokens]  |  [System & Tasks]  |  [Quotas]"
    echo -e ""
    echo -e "\033[1mICONS & METRICS:\033[0m"
    echo -e "  \033[1m READY /  WORKING\033[0m   Agent state. Changes color when processing or running tools."
    echo -e "  \033[1m Gemini 3.1 Pro\033[0m      Active model."
    echo -e "  \033[1m ~ / main*\033[0m           Current directory and Git branch. Adds * if dirty."
    echo -e "  \033[1m󱍏 11.6%\033[0m               Context window usage. Hits 100% when memory is full."
    echo -e "  \033[1m 121K/45K (+119K/1K)\033[0m Token tracking. Format is Input / Output. Left side is total session usage."
    echo -e "                        Right side (+turn) is tokens consumed during the very last prompt."
    echo -e "  \033[1m 76% 0.79\033[0m            Local machine RAM usage and 1-minute CPU load."
    echo -e "  \033[1m 4  󱙺 0   0\033[0m         Active artifacts, running subagents, and background tasks."
    echo -e "  \033[1m󰦜 host\033[0m                Execution mode. (host = direct local execution)."
    echo -e "  \033[1m5H 42.8% ⌛ 2h 48m\033[0m    5-hour API quota limit and countdown to reset."
    echo -e "  \033[1m7D 2.3% ⌛ 1d 20h\033[0m     Weekly API quota limit and countdown to reset."
    echo -e ""
    echo -e "\033[1mTHEMING:\033[0m"
    echo -e "  Colors are hardcoded to the Omarchy theme palette for maximum speed."
    exit 0
    fi
    USE_CLASSIC_ICONS=true
  fi
done

# Set dynamic width boundaries
if [ "$COLS" -ge 180 ]; then
  BAR_LEN=20
  QUOTA_BAR_LEN=15
else
  BAR_LEN=10
  QUOTA_BAR_LEN=8
fi

# Define Theme Colors and Icons
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  DOT_L1="${FG_GRAY} ╱ ${R}"
  DOT_L2="${FG_GRAY} · ${R}"
  ICON_READY="●"
  ICON_THINKING="◆"
  ICON_WORKING="⚙"
  ICON_TOOL="🔧"
  ICON_STATE_UNKNOWN="⏳"
  ICON_VCS="╱"
  ICON_MODEL=""
  ICON_SANDBOX_NET="ON (net)"
  ICON_SANDBOX_NONET="ON (no-net)"
  ICON_SANDBOX_OFF="OFF"
  ICON_CONTEXT_BAR="ctx"
  ICON_ARTIFACTS="artifacts"
  ICON_SUBAGENTS="subagents"
  ICON_TASKS="tasks"
  ICON_DIR="╱"
  ICON_CONV="╱"
  ICON_TOK_SUM=""
  ICON_RESET="⌛"
  ICON_AC="AC"
  ICON_BAT="BAT"
  ICON_SYS="sys"

  # Standard 16-color mappings for classic mode
  BG_READY="${FG_GREEN}"
  FG_READY_TEXT="${B}"
  BG_THINKING="${FG_YELLOW}"
  FG_THINKING_TEXT="${B}"
  BG_WORKING="${FG_CYAN}"
  FG_WORKING_TEXT="${B}"
  BG_TOOL="${FG_MAGENTA}"
  FG_TOOL_TEXT="${B}"
  BG_UNKNOWN="${FG_WHITE}"
  FG_UNKNOWN_TEXT="${B}"

  BG_GIT_CLEAN="${FG_BLUE}"
  FG_GIT_CLEAN_TEXT="${B}"
  BG_GIT_DIRTY="${FG_RED}"
  FG_GIT_DIRTY_TEXT="${B}"

  BG_MODEL="${FG_MAGENTA}"
  FG_MODEL_TEXT=""

  BG_DIR="${FG_CYAN}"
  FG_DIR_TEXT=""

  BG_META="${FG_GRAY}"
  FG_META_TEXT=""
else
  DOT_L1="${FG_GRAY} | ${R}"
  DOT_L2="${FG_GRAY} | ${R}"
  ICON_READY=""
  ICON_THINKING="󰟷"
  ICON_WORKING=""
  ICON_TOOL=""
  ICON_STATE_UNKNOWN=""
  ICON_VCS=""
  ICON_MODEL=""
  ICON_SANDBOX_NET="󰒙"
  ICON_SANDBOX_NONET="󰴴"
  ICON_SANDBOX_OFF="󰦜"
  ICON_CONTEXT_BAR="󱍏"
  ICON_ARTIFACTS=""
  ICON_SUBAGENTS="󱙺"
  ICON_TASKS=""
  ICON_DIR=""
  ICON_CONV="󰍪"
  ICON_TOK_SUM=""
  ICON_RESET="⌛️"
  ICON_AC="󰚥"
  ICON_BAT="🔋"
  ICON_SYS=""

  # Omarchy RGB minimal text palette mappings
  BG_READY=""
  FG_READY_TEXT="\033[38;2;95;135;95m\033[1m"
  
  BG_THINKING=""
  FG_THINKING_TEXT="\033[38;2;201;165;84m\033[1m"
  
  BG_WORKING=""
  FG_WORKING_TEXT="\033[38;2;120;130;75m\033[1m"
  
  BG_TOOL=""
  FG_TOOL_TEXT="\033[38;2;179;109;67m\033[1m"
  
  BG_UNKNOWN=""
  FG_UNKNOWN_TEXT="\033[38;2;194;194;176m\033[1m"
  
  BG_GIT_CLEAN=""
  FG_GIT_CLEAN_TEXT="\033[38;2;194;194;176m\033[1m"
  
  BG_GIT_DIRTY=""
  FG_GIT_DIRTY_TEXT="\033[38;2;104;87;66m\033[1m"
  
  BG_MODEL=""
  FG_MODEL_TEXT="\033[38;2;194;194;176m\033[1m"
  
  BG_DIR=""
  FG_DIR_TEXT="\033[38;2;194;194;176m\033[1m"
  
  BG_META=""
  FG_META_TEXT="\033[38;2;102;102;102m"
fi

# ─── Git Timeout Resilience Wrapper ──────────────────────────────────────────
run_with_timeout() {
  if command -v timeout &>/dev/null; then
    timeout 1 "$@"
  else
    "$@"
  fi
}

GIT_DIR="${CWD:-.}"
VCS_BRANCH=$(run_with_timeout git -C "$GIT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$VCS_BRANCH" ]; then
  VCS_TYPE="git"
  if run_with_timeout git -C "$GIT_DIR" status --porcelain 2>/dev/null | grep -q .; then
    VCS_DIRTY="true"
  else
    VCS_DIRTY="false"
  fi
else
  VCS_TYPE=""
  VCS_DIRTY="false"
fi

# ─── Dynamic CPU load & RAM diagnostics (Pure Bash, instant) ────────────────
MEM_PCT=""
LOAD_1M=""
if [ -f /proc/meminfo ]; then
  mem_total=0
  mem_avail=0
  while read -r name value unit; do
    if [ "$name" = "MemTotal:" ]; then
      mem_total=$value
    elif [ "$name" = "MemAvailable:" ]; then
      mem_avail=$value
      break
    fi
  done < /proc/meminfo
  if [ "$mem_total" -gt 0 ]; then
    MEM_PCT=$(( (mem_total - mem_avail) * 100 / mem_total ))
  fi
fi
if [ -f /proc/loadavg ]; then
  read -r load_1m rest < /proc/loadavg
  LOAD_1M=$load_1m
fi

# ─── Helpers for values ──────────────────────────────────────────────────────
PCT_FMT=$(LC_NUMERIC=C printf "%.1f" "$USED_PCT" 2>/dev/null || echo "0.0")
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}

human_format() {
  local num=$1
  if [ -z "$num" ] || [ "$num" -eq 0 ] 2>/dev/null; then
    echo "0"
    return
  fi
  if [ "$num" -ge 1000000 ] 2>/dev/null; then
    echo "$((num / 1000000)).$(((num % 1000000) / 100000))M"
  elif [ "$num" -ge 1000 ] 2>/dev/null; then
    echo "$((num / 1000)).$(((num % 1000) / 100))K"
  else
    echo "$num"
  fi
}

INPUT_TOK_FMT=$(human_format "$INPUT_TOKENS")
OUTPUT_TOK_FMT=$(human_format "$OUTPUT_TOKENS")
CTX_LIMIT_FMT=$(human_format "$CTX_LIMIT")
CTX_USED_FMT=$(human_format "$CTX_USED")
TURN_INPUT_FMT=$(human_format "$TURN_INPUT_TOKENS")
TURN_OUTPUT_FMT=$(human_format "$TURN_OUTPUT_TOKENS")

shorten_path() {
  local path=$1
  if [ -z "$path" ]; then
    echo ""
    return
  fi
  path="${path/#$HOME/\~}"
  if [ "${#path}" -gt 25 ]; then
    echo "...$(basename "$path")"
  else
    echo "$path"
  fi
}
CWD_SHORT=$(shorten_path "$CWD")

visible_len() {
  printf '%s' "$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')" | wc -m
}

# Get Tailscale and Host Info
HOST_NAME=$(hostname 2>/dev/null || echo "")
TS_IP=$(ip -4 addr show dev tailscale0 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2 || echo "")
HOST_INFO=""
if [ -n "$HOST_NAME" ]; then
  if [ -n "$TS_IP" ]; then
    HOST_INFO="${HOST_NAME} (${TS_IP})"
  else
    HOST_INFO="${HOST_NAME}"
  fi
fi

# ─── Power / Battery Scanner ─────────────────────────────────────────────────
POWER_FMT=""
AC_ONLINE_PATH=""
BAT_CAP_PATH=""
MACOS_AC_ON=""
MACOS_BAT_CAP=""

if [ -d /sys/class/power_supply ]; then
  for path in /sys/class/power_supply/*/online; do
    if [ -f "$path" ]; then
      AC_ONLINE_PATH="$path"
      break
    fi
  done
  for path in /sys/class/power_supply/*/capacity; do
    if [ -f "$path" ]; then
      BAT_CAP_PATH="$path"
      break
    fi
  done
elif command -v pmset &>/dev/null; then
  pmset_out=$(pmset -g batt 2>/dev/null || echo "")
  if echo "$pmset_out" | grep -q "AC Power"; then
    MACOS_AC_ON="1"
  else
    MACOS_AC_ON="0"
  fi
  MACOS_BAT_CAP=$(echo "$pmset_out" | grep -o "[0-9]\{1,3\}%" | tr -d "%" | head -n 1 || echo "")
fi

# ─── Segment powerline formatter ──────────────────────────────────────────────
make_segment() {
  local bg_color="$1"
  local fg_text="$2"
  local text="$3"
  local next_bg="$4"
  
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    echo -n "${fg_text}${text}${R} "
    return
  fi

  if [ -n "$next_bg" ]; then
    echo -n "${fg_text} ${text} \033[0m\033[38;2;102;102;102m|\033[0m"
  else
    echo -n "${fg_text} ${text} \033[0m"
  fi
}

to_ansi_color() {
  local code="$1"
  case "$code" in
    75)  echo -n "${FG_BRIGHT_BLUE}" ;;
    37)  echo -n "${FG_BRIGHT_CYAN}" ;;
    135) echo -n "${FG_BRIGHT_MAGENTA}" ;;
    76)  echo -n "${FG_BRIGHT_GREEN}" ;;
    197) echo -n "${FG_BRIGHT_RED}" ;;
    214) echo -n "${FG_BRIGHT_YELLOW}" ;;
    244) echo -n "${FG_GRAY}" ;;
    *)   echo -n "" ;;
  esac
}

# ─── Rounded Pill badge formatter ─────────────────────────────────────────────
make_badge() {
  local icon="$1"
  local val="$2"
  local icon_color="$3"
  local text_color="2;194;194;176"
  local icon_rgb="2;102;102;102"
  
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    echo -n "${icon} ${val}${R}"
    return
  fi

  echo -n "\033[38;${icon_rgb}m${icon} \033[38;${text_color}m${val}\033[0m"
}

# ─── Quota formatting ────────────────────────────────────────────────────────
format_reset_time() {
  local sec=$1
  if [ -z "$sec" ] || [ "$sec" -le 0 ]; then
    echo -n ""
    return
  fi

  local days=$((sec / 86400))
  local rem=$((sec % 86400))
  local hours=$((rem / 3600))
  rem=$((rem % 3600))
  local mins=$((rem / 60))

  if [ "$days" -gt 0 ]; then
    if [ "$hours" -gt 0 ]; then
      echo -n "${days}d ${hours}h"
    else
      echo -n "${days}d"
    fi
  elif [ "$hours" -gt 0 ]; then
    if [ "$mins" -gt 0 ]; then
      echo -n "${hours}h ${mins}m"
    else
      echo -n "${hours}h"
    fi
  elif [ "$mins" -gt 0 ]; then
    echo -n "${mins}m"
  else
    echo -n "<1m"
  fi
}

make_quota_bar() {
  local val=$1
  local label=$2
  local bar_color_num=$3
  local reset_sec=$4
  
  local reset_label=" ${ICON_RESET} "
  local separator=""
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    separator="${FG_GRAY} | ${R}"
  else
    separator=" \033[38;2;102;102;102m|\033[0m "
  fi
  
  if [ -z "$val" ] || [[ "$val" == -* ]]; then
    echo -n "${separator}\033[38;2;102;102;102m${label}\033[0m \033[38;2;194;194;176mN/A\033[0m"
    return
  fi

  local reset_str=""
  if [ -n "$reset_sec" ] && [ "$reset_sec" -gt 0 ]; then
    reset_str="${reset_label}$(format_reset_time "$reset_sec")"
  fi

  local text_color="2;194;194;176"
  local val_int=${val%.*}
  val_int=${val_int:-0}
  if [ "$val_int" -lt 20 ]; then
    text_color="2;104;87;66"
  elif [ "$val_int" -lt 50 ]; then
    text_color="2;201;165;84"
  fi

  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    echo -n "${separator}${label} ${val}%${reset_str}"
  else
    echo -n "${separator}\033[38;2;102;102;102m${label}\033[0m \033[38;${text_color}m${val}%\033[0m${reset_str}"
  fi
}

# Determine active quota based on actual availability
IS_3P=false
case "$MODEL_ID" in
  *[Cc][Ll][Aa][Uu][Dd][Ee]*|*[Gg][Pp][Tt]*|*[Aa][Nn][Tt][Hh][Rr][Oo][Pp][Ii][Cc]*|*[Oo][Pp][Ee][Nn][Aa][Ii]*|*[Oo]1*|*[Oo]3*|*3[Pp]*)
    IS_3P=true
    ;;
esac

if [ "$IS_3P" = true ]; then
  if { [ -n "$TP_5H" ] && [ "$TP_5H" != "-1" ]; } || { [ -n "$TP_WK" ] && [ "$TP_WK" != "-1" ]; }; then
    Q_5H="$TP_5H"
    Q_WK="$TP_WK"
    Q_5H_R="$TP_5H_RESET"
    Q_WK_R="$TP_WK_RESET"
  elif { [ -n "$GEMINI_5H" ] && [ "$GEMINI_5H" != "-1" ]; } || { [ -n "$GEMINI_WK" ] && [ "$GEMINI_WK" != "-1" ]; }; then
    Q_5H="$GEMINI_5H"
    Q_WK="$GEMINI_WK"
    Q_5H_R="$GEMINI_5H_RESET"
    Q_WK_R="$GEMINI_WK_RESET"
  else
    Q_5H="-1"
    Q_WK="-1"
    Q_5H_R="-1"
    Q_WK_R="-1"
  fi
else
  if { [ -n "$GEMINI_5H" ] && [ "$GEMINI_5H" != "-1" ]; } || { [ -n "$GEMINI_WK" ] && [ "$GEMINI_WK" != "-1" ]; }; then
    Q_5H="$GEMINI_5H"
    Q_WK="$GEMINI_WK"
    Q_5H_R="$GEMINI_5H_RESET"
    Q_WK_R="$GEMINI_WK_RESET"
  elif { [ -n "$TP_5H" ] && [ "$TP_5H" != "-1" ]; } || { [ -n "$TP_WK" ] && [ "$TP_WK" != "-1" ]; }; then
    Q_5H="$TP_5H"
    Q_WK="$TP_WK"
    Q_5H_R="$TP_5H_RESET"
    Q_WK_R="$TP_WK_RESET"
  else
    Q_5H="-1"
    Q_WK="-1"
    Q_5H_R="-1"
    Q_WK_R="-1"
  fi
fi


if [ "${Q_5H_R:- -1}" -gt 0 ] 2>/dev/null; then
  Q_5H_R=$(_tick_countdown "$Q_5H_R" "/tmp/agy_quota_5h_reset")
fi
if [ "${Q_WK_R:- -1}" -gt 0 ] 2>/dev/null; then
  Q_WK_R=$(_tick_countdown "$Q_WK_R" "/tmp/agy_quota_wk_reset")
fi

QUOTA_FMT=""
if { [ -n "$Q_5H" ] && [ "$Q_5H" != "-1" ]; } || { [ -n "$Q_WK" ] && [ "$Q_WK" != "-1" ]; }; then
  QUOTA_FMT="$(make_quota_bar "$Q_5H" "5H" "37" "$Q_5H_R") $(make_quota_bar "$Q_WK" "7D" "135" "$Q_WK_R")"
fi

# Right-align printing helper
print_right_aligned() {
  local left="$1"
  local right="$2"
  local total_cols="$3"

  local left_vis right_vis pad
  left_vis=$(visible_len "$left")
  right_vis=$(visible_len "$right")

  pad=$(( total_cols - left_vis - right_vis ))
  [ "$pad" -lt 1 ] && pad=1

  printf "%b%*s%b\n" "$left" "$pad" "" "$right"
}

# ─── Context Bar Formatting ──────────────────────────────────────────────────
FILLED=$((PCT_INT * BAR_LEN / 100))
REMAINDER=$(( (PCT_INT * BAR_LEN) % 100 ))

if   [ "$PCT_INT" -ge 90 ]; then FILL_COLOR="$FG_BRIGHT_RED"
elif [ "$PCT_INT" -ge 60 ]; then FILL_COLOR="$FG_BRIGHT_YELLOW"
else                              FILL_COLOR="$FG_YELLOW"
fi

if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  BAR=""
  for ((i = 0; i < BAR_LEN; i++)); do
    if   [ "$i" -lt "$FILLED" ]; then
      BAR="${BAR}█"
    elif [ "$i" -eq "$FILLED" ]; then
      if   [ "$REMAINDER" -ge 75 ]; then BAR="${BAR}▓"
      elif [ "$REMAINDER" -ge 50 ]; then BAR="${BAR}▒"
      elif [ "$REMAINDER" -ge 25 ]; then BAR="${BAR}░"
      else                               BAR="${BAR}·"
      fi
    else BAR="${BAR}·"
    fi
  done
  CTX_BAR="${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"
else
  # Color palette based on context size
  if [ "$PCT_INT" -ge 90 ]; then bar_c="197"; else bar_c="214"; fi
  BAR=""
  for ((i = 0; i < BAR_LEN; i++)); do
    if   [ "$i" -lt "$FILLED" ]; then
      BAR="${BAR}\033[38;5;${bar_c}m█\033[0m"
    elif [ "$i" -eq "$FILLED" ]; then
      if   [ "$REMAINDER" -ge 75 ]; then
        BAR="${BAR}\033[38;5;${bar_c}m▓\033[0m"
      elif [ "$REMAINDER" -ge 50 ]; then
        BAR="${BAR}\033[38;5;${bar_c}m▒\033[0m"
      else
        BAR="${BAR}\033[38;5;${bar_c}m░\033[0m"
      fi
    else
      BAR="${BAR}\033[38;5;236m░\033[0m"
    fi
  done
  
  # Pill badge for Context Bar
  label_bg="236"
  bar_bg="235"
  CTX_BAR="\033[38;2;102;102;102m${ICON_CONTEXT_BAR} \033[38;2;194;194;176m${PCT_FMT}%\033[0m"
fi

# ─── Statistics & Telemetry Badges ──────────────────────────────────────────
ART_FMT=$(make_badge "${ICON_ARTIFACTS}" "${ARTIFACTS}" "75")
SUB_FMT=$(make_badge "${ICON_SUBAGENTS}" "${SUBAGENTS}" "37")
BG_FMT=$(make_badge "${ICON_TASKS}" "${BG_TASKS}" "135")

# System Resources (RAM & Load average)
SYS_FMT=""
if [ -n "$MEM_PCT" ] && [ -n "$LOAD_1M" ]; then
  sys_color="76"
  load_int=${LOAD_1M%.*}
  load_int=${load_int:-0}
  if [ "$MEM_PCT" -ge 80 ] 2>/dev/null || [ "$load_int" -ge 8 ] 2>/dev/null; then
    sys_color="197"
  elif [ "$MEM_PCT" -ge 65 ] 2>/dev/null; then
    sys_color="214"
  fi
  SYS_FMT=$(make_badge "${ICON_SYS}" "${MEM_PCT}% ${LOAD_1M}" "$sys_color")
fi

# Sandbox Badge
SB_FMT=""
if [ "$SANDBOX" = "true" ]; then
  if [ "$SANDBOX_NET" = "true" ]; then
    SB_FMT=$(make_badge "${ICON_SANDBOX_NET}" "net-on" "76")
  else
    SB_FMT=$(make_badge "${ICON_SANDBOX_NONET}" "net-off" "214")
  fi
else
  SB_FMT=$(make_badge "${ICON_SANDBOX_OFF}" "host" "244")
fi

# Power Badge
POWER_FMT=""
if [ -n "$AC_ONLINE_PATH" ]; then
  AC_ON=$(cat "$AC_ONLINE_PATH" 2>/dev/null || echo "1")
  BAT_CAP=""
  if [ -n "$BAT_CAP_PATH" ]; then
    BAT_CAP=$(cat "$BAT_CAP_PATH" 2>/dev/null || echo "")
  fi
  
  if [ "$AC_ON" = "0" ]; then
    label="BAT"
    if [ -n "$BAT_CAP" ]; then
      label="${BAT_CAP}%"
    fi
    POWER_FMT=$(make_badge "${ICON_BAT}" "$label" "214")
  else
    POWER_FMT=$(make_badge "${ICON_AC}" "AC" "76")
  fi
elif [ -n "$MACOS_AC_ON" ]; then
  if [ "$MACOS_AC_ON" = "0" ]; then
    label="BAT"
    if [ -n "$MACOS_BAT_CAP" ]; then
      label="${MACOS_BAT_CAP}%"
    fi
    POWER_FMT=$(make_badge "${ICON_BAT}" "$label" "214")
  else
    POWER_FMT=$(make_badge "${ICON_AC}" "AC" "76")
  fi
fi

# Token counters
TOK_DETAILS_WIDE=""
TOK_DETAILS_MED=""
if [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
  turn_str=""
  if [ "$TURN_INPUT_TOKENS" -gt 0 ] || [ "$TURN_OUTPUT_TOKENS" -gt 0 ]; then
    turn_str=" | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
  fi
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    TOK_DETAILS_WIDE=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT_L2}(total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})"
    TOK_DETAILS_MED=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
  else
    TOK_DETAILS_WIDE=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT_L2}${FG_YELLOW}${ICON_TOK_SUM} ${R} (total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})"
    TOK_DETAILS_MED=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
  fi
fi

MODEL_DISP="${MODEL_NAME:-$MODEL_ID}"
MODEL_DISP="${MODEL_DISP#Gemini }"
MODEL_DISP="${MODEL_DISP#Claude }"
MODEL_DISP="${MODEL_DISP#GPT-OSS }"

# ─── Dynamic LINE1 Assembly (Powerline segments) ────────────────────────────
ACTIVE_SEGS=()
ACTIVE_BGS=()
ACTIVE_FGS=()

# 1. State
case "$STATE" in
  idle)     
    ACTIVE_SEGS+=("${ICON_READY} READY")
    ACTIVE_BGS+=("$BG_READY")
    ACTIVE_FGS+=("$FG_READY_TEXT")
    S="${FG_BRIGHT_GREEN}${B} ${ICON_READY} READY${R}"
    ;;
  thinking) 
    ACTIVE_SEGS+=("${ICON_THINKING} THINKING")
    ACTIVE_BGS+=("$BG_THINKING")
    ACTIVE_FGS+=("$FG_THINKING_TEXT")
    S="${FG_BRIGHT_YELLOW}${B} ${ICON_THINKING} THINKING${R}"
    ;;
  working)  
    ACTIVE_SEGS+=("${ICON_WORKING} WORKING")
    ACTIVE_BGS+=("$BG_WORKING")
    ACTIVE_FGS+=("$FG_WORKING_TEXT")
    S="${FG_BRIGHT_CYAN}${B} ${ICON_WORKING} WORKING${R}"
    ;;
  tool_use) 
    ACTIVE_SEGS+=("${ICON_TOOL} TOOL")
    ACTIVE_BGS+=("$BG_TOOL")
    ACTIVE_FGS+=("$FG_TOOL_TEXT")
    S="${FG_BRIGHT_MAGENTA}${B} ${ICON_TOOL} TOOL${R}"
    ;;
  *)        
    ACTIVE_SEGS+=("${ICON_STATE_UNKNOWN} $(echo "$STATE" | tr '[:lower:]' '[:upper:]')")
    ACTIVE_BGS+=("$BG_UNKNOWN")
    ACTIVE_FGS+=("$FG_UNKNOWN_TEXT")
    S="${FG_WHITE}${B} ${ICON_STATE_UNKNOWN} $(echo "$STATE" | tr '[:lower:]' '[:upper:]')${R}"
    ;;
esac

# 2. VCS Branch
if [ -n "$VCS_BRANCH" ]; then
  if [ "$VCS_DIRTY" = "true" ]; then
    ACTIVE_SEGS+=("${ICON_VCS} ${VCS_BRANCH}*")
    ACTIVE_BGS+=("$BG_GIT_DIRTY")
    ACTIVE_FGS+=("$FG_GIT_DIRTY_TEXT")
  else
    ACTIVE_SEGS+=("${ICON_VCS} ${VCS_BRANCH}")
    ACTIVE_BGS+=("$BG_GIT_CLEAN")
    ACTIVE_FGS+=("$FG_GIT_CLEAN_TEXT")
  fi
fi

# 3. Model
if [ -n "$MODEL_DISP" ]; then
  ACTIVE_SEGS+=("${ICON_MODEL} ${MODEL_DISP}")
  ACTIVE_BGS+=("$BG_MODEL")
  ACTIVE_FGS+=("$FG_MODEL_TEXT")
fi

# 4. Directory
if [ -n "$CWD_SHORT" ]; then
  ACTIVE_SEGS+=("${ICON_DIR} ${CWD_SHORT}")
  ACTIVE_BGS+=("$BG_DIR")
  ACTIVE_FGS+=("$FG_DIR_TEXT")
fi

# 5. User Plan & Account
if false; then
  u_label="${PLAN_TIER}"
  if [ -n "$USER_EMAIL" ]; then
    if [ -n "$u_label" ]; then
      u_label="${u_label} (${USER_EMAIL})"
    else
      u_label="${USER_EMAIL}"
    fi
  fi
  if [ "$COLS" -ge 130 ]; then
    if [ "$USE_CLASSIC_ICONS" = "true" ]; then
      ACTIVE_SEGS+=("${u_label}")
    else
      ACTIVE_SEGS+=("👤 ${u_label}")
    fi
    ACTIVE_BGS+=("$BG_META")
    ACTIVE_FGS+=("$FG_META_TEXT")
  fi
fi

# 6. Conversation
if false; then
  ACTIVE_SEGS+=("${ICON_CONV} ${CONV_ID:0:8}")
  ACTIVE_BGS+=("$BG_META")
  ACTIVE_FGS+=("$FG_META_TEXT")
fi

# 6. Host IP
if false; then
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    ACTIVE_SEGS+=("${HOST_INFO}")
  else
    ACTIVE_SEGS+=("󰒋 ${HOST_INFO}")
  fi
  ACTIVE_BGS+=("$BG_META")
  ACTIVE_FGS+=("$FG_META_TEXT")
fi

# 7. Version
if false; then
  ACTIVE_SEGS+=("v${CLI_VERSION}")
  ACTIVE_BGS+=("$BG_META")
  ACTIVE_FGS+=("$FG_META_TEXT")
fi

# Assemble LINE1 with powerline transitions
LINE1=""
num_segs=${#ACTIVE_SEGS[@]}
for ((i = 0; i < num_segs; i++)); do
  next_bg=""
  if [ "$((i + 1))" -lt "$num_segs" ]; then
    next_bg="${ACTIVE_BGS[i+1]}"
  fi
  LINE1="${LINE1}$(make_segment "${ACTIVE_BGS[i]}" "${ACTIVE_FGS[i]}" "${ACTIVE_SEGS[i]}" "$next_bg")"
done

# ─── Smart Dynamic Line-Packing Engine ───────────────────────────────────────
# Collect all active telemetry badges into an ordered array
BADGE_LIST=()

# 1. Context Usage Bar
[ -n "$CTX_BAR" ] && BADGE_LIST+=("$CTX_BAR")

# 2. Token Details Badge
if [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
  turn_str=""
  if [ "$TURN_INPUT_TOKENS" -gt 0 ] || [ "$TURN_OUTPUT_TOKENS" -gt 0 ]; then
    turn_str=" | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
  fi
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    BADGE_LIST+=("(total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})")
  else
    BADGE_LIST+=("$(make_badge "${ICON_TOK_SUM}" "total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str}" "220")")
  fi
fi

# 3. System Resources (RAM & Load)
[ -n "$SYS_FMT" ] && BADGE_LIST+=("$SYS_FMT")

# 4. Artifacts Counter
[ -n "$ART_FMT" ] && BADGE_LIST+=("$ART_FMT")

# 5. Subagents Counter
[ -n "$SUB_FMT" ] && BADGE_LIST+=("$SUB_FMT")

# 6. Background Tasks Counter
[ -n "$BG_FMT" ] && BADGE_LIST+=("$BG_FMT")

# 7. Sandbox Status
[ -n "$SB_FMT" ] && BADGE_LIST+=("$SB_FMT")

# 8. Quotas
if { [ -n "$Q_5H" ] && [ "$Q_5H" != "-1" ]; }; then
  BADGE_LIST+=("$(make_quota_bar "$Q_5H" "5H" "37" "$Q_5H_R")")
fi
if { [ -n "$Q_WK" ] && [ "$Q_WK" != "-1" ]; }; then
  BADGE_LIST+=("$(make_quota_bar "$Q_WK" "7D" "135" "$Q_WK_R")")
fi

# 9. Power Status
if false; then BADGE_LIST+=("$POWER_FMT"); fi

# Greedy Line-Packing Routine
PACKED_LINES=()
curr_line=""
curr_vis=0
max_vis=$(( COLS - 4 ))
if [ "$max_vis" -lt 40 ]; then max_vis=40; fi

for badge in "${BADGE_LIST[@]}"; do
  [ -z "$badge" ] && continue
  b_vis=$(visible_len "$badge")
  
  if [ -z "$curr_line" ]; then
    curr_line="$badge"
    curr_vis=$b_vis
  elif [ $(( curr_vis + 2 + b_vis )) -le "$max_vis" ]; then
    curr_line="${curr_line}  ${badge}"
    curr_vis=$(( curr_vis + 2 + b_vis ))
  else
    PACKED_LINES+=("$curr_line")
    curr_line="$badge"
    curr_vis=$b_vis
  fi
done
[ -n "$curr_line" ] && PACKED_LINES+=("$curr_line")

# Output rendering with minimal style
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  echo -e "${LINE1}"
  for pline in "${PACKED_LINES[@]}"; do
    echo -e "${pline}"
  done
else
  out=" ${LINE1}"
  total_packed=${#PACKED_LINES[@]}
  for ((i = 0; i < total_packed; i++)); do
    out="${out}  \033[38;2;102;102;102m|\033[0m ${PACKED_LINES[i]}"
  done
  echo -e "$out"
fi
