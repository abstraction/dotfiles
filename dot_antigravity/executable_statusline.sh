#!/bin/bash
# statusline.sh - Minimal & Responsive Telemetry Statusline for Antigravity CLI
# Built with Omarchy minimalist theme, prompt cache awareness, and responsive wrapping

set -euo pipefail
export LC_NUMERIC=C

for arg in "$@"; do
  if [ "$arg" = "--version" ] || [ "$arg" = "-v" ]; then
    echo "Antigravity CLI Statusline v0.3.1"
    exit 0
  fi
  if [ "$arg" = "--legend" ] || [ "$arg" = "-l" ] || [ "$arg" = "legend" ]; then
    echo -e "\033[38;2;120;130;75m\033[1m🚀 Minimal Omarchy Statusline Legend (v0.3.1)\033[0m"
    echo -e "A high-density, responsive telemetry statusline that dynamically adapts to split panes."
    echo -e ""
    echo -e "\033[1mLAYOUT & RESPONSIVENESS:\033[0m"
    echo -e "  - \033[1mWide terminals (>= 130 cols):\033[0m All segments render on a single, unified flat line."
    echo -e "  - \033[1mSplit panes (< 130 cols):\033[0m Intelligently wraps into 2 (or 3) balanced lines without clipping."
    echo -e "  - \033[1mNarrow panes (< 75 cols):\033[0m Compacts paths to basenames and shortens model and cache labels."
    echo -e ""
    echo -e "\033[1mCOMPONENTS & METRICS:\033[0m"
    echo -e "  \033[38;2;95;135;95m\033[1m READY\033[0m / \033[38;2;120;130;75m\033[1m WORKING\033[0m   Agent state (READY, WORKING, THINKING, TOOL)."
    echo -e "  \033[38;2;194;194;176m\033[1m main*\033[0m                   Git branch with dirty indicator (*)."
    echo -e "  \033[38;2;194;194;176m 3.8 Flash\033[0m               Active model with vendor prefixes stripped."
    echo -e "  \033[38;2;194;194;176m ~/my/think/temp\033[0m        Current working directory."
    echo -e "  \033[38;2;194;194;176m󱍏 8.8%\033[0m                   Active context window fill percentage (warns at 50% / 80%)."
    echo -e "  \033[38;2;194;194;176mturn: 82K in (77K cached) │ 4.2K out\033[0m"
    echo -e "                        Accurate prompt accounting matching the CLI header. Shows total"
    echo -e "                        prompt size, prompt cache hits, and generated output tokens."
    echo -e "  \033[38;2;194;194;176mctx: 33.6K/1M\033[0m         Shown when idle before first turn: context tokens vs window limit."
    echo -e "  \033[38;2;120;130;75m 2\033[0m  \033[38;2;95;135;95m󱙺 1\033[0m  \033[38;2;201;165;84m 1\033[0m         Progressive disclosure: artifacts, subagents, and tasks"
    echo -e "                        appear only when active (> 0). Zero-counts are omitted."
    echo -e "  \033[38;2;102;102;102m5H 77.6% ⌛ 3h 54m\033[0m    5-hour and 7-day quota trackers with live reset countdowns."
    exit 0
  fi
done

# ─── Stdin Timeout Guard ──────────────────────────────────────────────────────
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

# ─── Parse JSON from stdin (Single jq pass) ──────────────────────────────────
{
  read -r STATE
  read -r USED_PCT
  read -r VCS_BRANCH
  read -r VCS_DIRTY
  read -r SANDBOX
  read -r SANDBOX_NET
  read -r ARTIFACTS
  read -r SUBAGENTS
  read -r BG_TASKS
  read -r MODEL_ID
  read -r MODEL_NAME
  read -r COLS
  read -r CWD
  read -r CTX_LIMIT
  read -r CTX_USED
  read -r GEMINI_5H
  read -r GEMINI_WK
  read -r TP_5H
  read -r TP_WK
  read -r GEMINI_5H_RESET
  read -r GEMINI_WK_RESET
  read -r TP_5H_RESET
  read -r TP_WK_RESET
  read -r TURN_INPUT_TOKENS
  read -r TURN_CACHE_TOKENS
  read -r TURN_OUTPUT_TOKENS
} <<< "$(
  printf '%s' "$INPUT_JSON" | jq -r '
    (.agent_state // "idle"),
    (.context_window.used_percentage // 0),
    (.vcs.branch // ""),
    (.vcs.dirty // false),
    (.sandbox.enabled // false),
    (.sandbox.allow_network // false),
    (.artifact_count // 0),
    (if .subagents | type == "array" then (.subagents | length) else 0 end),
    (.task_count // 0),
    (.model.id // ""),
    (.model.display_name // ""),
    (.terminal_width // 80),
    (.cwd // ""),
    (.context_window.context_window_size // 0),
    (.context_window.total_input_tokens // 0),
    (if .quota["gemini-5h"].remaining_fraction != null then ((.quota["gemini-5h"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["gemini-weekly"].remaining_fraction != null then ((.quota["gemini-weekly"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["3p-5h"].remaining_fraction != null then ((.quota["3p-5h"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["3p-weekly"].remaining_fraction != null then ((.quota["3p-weekly"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (.quota["gemini-5h"].reset_in_seconds // -1),
    (.quota["gemini-weekly"].reset_in_seconds // -1),
    (.quota["3p-5h"].reset_in_seconds // -1),
    (.quota["3p-weekly"].reset_in_seconds // -1),
    ((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0)),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0)
  ' 2>/dev/null || printf "idle\n0\n\nfalse\nfalse\nfalse\n0\n0\n0\n\n\n80\n\n0\n0\n-1\n-1\n-1\n-1\n-1\n-1\n-1\n-1\n0\n0\n0\n"
)"

# ─── Numeric Sanitization ────────────────────────────────────────────────────
if ! [[ "$USED_PCT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then USED_PCT=0; fi
if ! [[ "$COLS" =~ ^[0-9]+$ ]]; then COLS=80; fi
if ! [[ "$ARTIFACTS" =~ ^[0-9]+$ ]]; then ARTIFACTS=0; fi
if ! [[ "$SUBAGENTS" =~ ^[0-9]+$ ]]; then SUBAGENTS=0; fi
if ! [[ "$BG_TASKS" =~ ^[0-9]+$ ]]; then BG_TASKS=0; fi
if ! [[ "$CTX_LIMIT" =~ ^[0-9]+$ ]]; then CTX_LIMIT=0; fi
if ! [[ "$CTX_USED" =~ ^[0-9]+$ ]]; then CTX_USED=0; fi
if ! [[ "$TURN_INPUT_TOKENS" =~ ^[0-9]+$ ]]; then TURN_INPUT_TOKENS=0; fi
if ! [[ "$TURN_CACHE_TOKENS" =~ ^[0-9]+$ ]]; then TURN_CACHE_TOKENS=0; fi
if ! [[ "$TURN_OUTPUT_TOKENS" =~ ^[0-9]+$ ]]; then TURN_OUTPUT_TOKENS=0; fi

if ! [[ "$GEMINI_5H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then GEMINI_5H="-1"; fi
if ! [[ "$GEMINI_WK" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then GEMINI_WK="-1"; fi
if ! [[ "$TP_5H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then TP_5H="-1"; fi
if ! [[ "$TP_WK" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then TP_WK="-1"; fi

if ! [[ "$GEMINI_5H_RESET" =~ ^[0-9]+$ ]]; then GEMINI_5H_RESET="-1"; fi
if ! [[ "$GEMINI_WK_RESET" =~ ^[0-9]+$ ]]; then GEMINI_WK_RESET="-1"; fi
if ! [[ "$TP_5H_RESET" =~ ^[0-9]+$ ]]; then TP_5H_RESET="-1"; fi
if ! [[ "$TP_WK_RESET" =~ ^[0-9]+$ ]]; then TP_WK_RESET="-1"; fi

# ─── Quota Countdown Helpers ─────────────────────────────────────────────────
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

format_reset_time() {
  local sec=$1
  if [ -z "$sec" ] || [ "$sec" -le 0 ]; then echo -n ""; return; fi
  local days=$((sec / 86400))
  local rem=$((sec % 86400))
  local hours=$((rem / 3600))
  rem=$((rem % 3600))
  local mins=$((rem / 60))

  if [ "$days" -gt 0 ]; then
    [ "$hours" -gt 0 ] && echo -n "${days}d ${hours}h" || echo -n "${days}d"
  elif [ "$hours" -gt 0 ]; then
    [ "$mins" -gt 0 ] && echo -n "${hours}h ${mins}m" || echo -n "${hours}h"
  elif [ "$mins" -gt 0 ]; then
    echo -n "${mins}m"
  else
    echo -n "<1m"
  fi
}

make_quota_bar() {
  local val=$1
  local label=$2
  local reset_sec=$3
  if [ -z "$val" ] || [[ "$val" == -* ]]; then return; fi
  local reset_str=""
  if [ -n "$reset_sec" ] && [ "$reset_sec" -gt 0 ]; then
    reset_str=" ⌛ $(format_reset_time "$reset_sec")"
  fi
  local text_color="2;194;194;176"
  local val_int=${val%.*}; val_int=${val_int:-0}
  if [ "$val_int" -lt 20 ]; then
    text_color="2;179;109;67"
  elif [ "$val_int" -lt 50 ]; then
    text_color="2;201;165;84"
  fi
  echo -n "\033[38;2;102;102;102m${label}\033[0m \033[38;${text_color}m${val}%\033[0m${reset_str}"
}

make_badge() {
  local icon="$1"
  local val="$2"
  local icon_rgb="$3"
  echo -n "\033[38;2;${icon_rgb}m${icon}\033[0m \033[38;2;194;194;176m${val}\033[0m"
}

# ─── Formatting Helpers ──────────────────────────────────────────────────────
human_format() {
  local num=$1
  if [ -z "$num" ] || [ "$num" -le 0 ] 2>/dev/null; then
    echo "0"
    return
  fi
  if [ "$num" -ge 1000000 ] 2>/dev/null; then
    local m=$(( num / 1000000 ))
    local d=$(( (num % 1000000) / 100000 ))
    if [ "$d" -eq 0 ]; then
      echo "${m}M"
    else
      echo "${m}.${d}M"
    fi
  elif [ "$num" -ge 1000 ] 2>/dev/null; then
    local k=$(( num / 1000 ))
    local d=$(( (num % 1000) / 100 ))
    if [ "$d" -eq 0 ]; then
      echo "${k}K"
    else
      echo "${k}.${d}K"
    fi
  else
    echo "$num"
  fi
}

shorten_path() {
  local path=$1
  [ -z "$path" ] && return
  path="${path/#$HOME/\~}"
  if [ "$COLS" -lt 75 ] 2>/dev/null; then
    echo "$(basename "$path")"
  elif [ "${#path}" -gt 25 ]; then
    echo "...$(basename "$path")"
  else
    echo "$path"
  fi
}

visible_len() {
  local clean
  clean=$(echo -e "$1" | sed -r "s/\x1b\[[0-9;]*[a-zA-Z]//g")
  echo "${#clean}"
}

# ─── Icons & Omarchy Theme Colors ────────────────────────────────────────────
ICON_READY=""
ICON_THINKING="󰟷"
ICON_WORKING=""
ICON_TOOL=""
ICON_STATE_UNKNOWN=""
ICON_VCS=""
ICON_MODEL=""
ICON_SANDBOX_NET="󰒙"
ICON_SANDBOX_NONET="󰴴"
ICON_CONTEXT_BAR="󱍏"
ICON_ARTIFACTS=""
ICON_SUBAGENTS="󱙺"
ICON_TASKS=""
ICON_DIR=""

# ─── Git Resolution ──────────────────────────────────────────────────────────
if [ -z "$VCS_BRANCH" ] && [ -n "$CWD" ]; then
  VCS_BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -n "$VCS_BRANCH" ]; then
    if git -C "$CWD" status --porcelain -uno 2>/dev/null | grep -q .; then
      VCS_DIRTY="true"
    fi
  fi
fi

# ─── Model Name Formatting (Responsive) ──────────────────────────────────────
MODEL_DISP="${MODEL_NAME:-$MODEL_ID}"
MODEL_DISP="${MODEL_DISP#Gemini }"
MODEL_DISP="${MODEL_DISP#Claude }"
MODEL_DISP="${MODEL_DISP#GPT-OSS }"

if [ "$COLS" -lt 70 ] 2>/dev/null; then
  MODEL_DISP="${MODEL_DISP%% *}"
elif [ "$COLS" -lt 95 ] 2>/dev/null; then
  MODEL_DISP="${MODEL_DISP%% (*}"
fi

# ─── Assemble LINE1 (Identity & State) ───────────────────────────────────────
ACTIVE_SEGS=()
case "$STATE" in
  idle)     ACTIVE_SEGS+=("\033[38;2;95;135;95m\033[1m${ICON_READY} READY\033[0m") ;;
  thinking) ACTIVE_SEGS+=("\033[38;2;201;165;84m\033[1m${ICON_THINKING} THINKING\033[0m") ;;
  working)  ACTIVE_SEGS+=("\033[38;2;120;130;75m\033[1m${ICON_WORKING} WORKING\033[0m") ;;
  tool_use) ACTIVE_SEGS+=("\033[38;2;179;109;67m\033[1m${ICON_TOOL} TOOL\033[0m") ;;
  *)        ACTIVE_SEGS+=("\033[38;2;194;194;176m\033[1m${ICON_STATE_UNKNOWN} ${STATE^^}\033[0m") ;;
esac

if [ -n "$VCS_BRANCH" ]; then
  if [ "$VCS_DIRTY" = "true" ]; then
    ACTIVE_SEGS+=("\033[38;2;104;87;66m\033[1m${ICON_VCS} ${VCS_BRANCH}*\033[0m")
  else
    ACTIVE_SEGS+=("\033[38;2;194;194;176m\033[1m${ICON_VCS} ${VCS_BRANCH}\033[0m")
  fi
fi

if [ -n "$MODEL_DISP" ]; then
  ACTIVE_SEGS+=("\033[38;2;194;194;176m${ICON_MODEL} ${MODEL_DISP}\033[0m")
fi

CWD_SHORT=$(shorten_path "$CWD")
if [ -n "$CWD_SHORT" ]; then
  ACTIVE_SEGS+=("\033[38;2;194;194;176m${ICON_DIR} ${CWD_SHORT}\033[0m")
fi

LINE1=""
for ((i = 0; i < ${#ACTIVE_SEGS[@]}; i++)); do
  if [ "$i" -gt 0 ]; then
    LINE1="${LINE1} \033[38;2;102;102;102m│\033[0m ${ACTIVE_SEGS[i]}"
  else
    LINE1="${ACTIVE_SEGS[i]}"
  fi
done

# ─── Assemble Badges (Progressive Disclosure & Accurate Tokens) ──────────────
BADGE_LIST=()

# 1. Context Window Usage Percentage
PCT_FMT=$(LC_NUMERIC=C printf "%.1f" "$USED_PCT" 2>/dev/null || echo "0.0")
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}
if [ -n "$USED_PCT" ]; then
  ctx_color="194;194;176"
  if [ "$PCT_INT" -ge 80 ]; then
    ctx_color="179;109;67"
  elif [ "$PCT_INT" -ge 50 ]; then
    ctx_color="201;165;84"
  fi
  BADGE_LIST+=("\033[38;2;102;102;102m${ICON_CONTEXT_BAR}\033[0m \033[38;2;${ctx_color}m${PCT_FMT}%\033[0m")
fi

# 2. Token Details Badge (Responsive & Cache-Aware)
TURN_IN_FMT=$(human_format "$TURN_INPUT_TOKENS")
TURN_CACHE_FMT=$(human_format "$TURN_CACHE_TOKENS")
TURN_OUT_FMT=$(human_format "$TURN_OUTPUT_TOKENS")
CTX_USED_FMT=$(human_format "$CTX_USED")
CTX_LIMIT_FMT=$(human_format "$CTX_LIMIT")

if [ "$TURN_INPUT_TOKENS" -gt 0 ] || [ "$TURN_OUTPUT_TOKENS" -gt 0 ]; then
  cache_str=""
  if [ "$TURN_CACHE_TOKENS" -gt 0 ]; then
    if [ "$COLS" -lt 75 ] 2>/dev/null; then
      cache_str=" \033[38;2;102;102;102m[${TURN_CACHE_FMT}⚡]\033[0m"
    else
      cache_str=" \033[38;2;102;102;102m(${TURN_CACHE_FMT} cached)\033[0m"
    fi
  fi
  BADGE_LIST+=("\033[38;2;102;102;102mturn:\033[0m \033[38;2;194;194;176m${TURN_IN_FMT} in\033[0m${cache_str} \033[38;2;102;102;102m│\033[0m \033[38;2;194;194;176m${TURN_OUT_FMT} out\033[0m")
elif [ "$CTX_USED" -gt 0 ] && [ "$CTX_LIMIT" -gt 0 ]; then
  BADGE_LIST+=("\033[38;2;102;102;102mctx:\033[0m \033[38;2;194;194;176m${CTX_USED_FMT}/${CTX_LIMIT_FMT}\033[0m")
fi

# 3. Artifacts Counter (Progressive disclosure: ONLY if > 0)
if [ "$ARTIFACTS" -gt 0 ] 2>/dev/null; then
  BADGE_LIST+=("$(make_badge "${ICON_ARTIFACTS}" "${ARTIFACTS}" "120;130;75")")
fi

# 4. Subagents Counter (Progressive disclosure: ONLY if > 0)
if [ "$SUBAGENTS" -gt 0 ] 2>/dev/null; then
  BADGE_LIST+=("$(make_badge "${ICON_SUBAGENTS}" "${SUBAGENTS}" "95;135;95")")
fi

# 5. Background Tasks Counter (Progressive disclosure: ONLY if > 0)
if [ "$BG_TASKS" -gt 0 ] 2>/dev/null; then
  BADGE_LIST+=("$(make_badge "${ICON_TASKS}" "${BG_TASKS}" "201;165;84")")
fi

# 6. Sandbox Status (Progressive disclosure: ONLY if enabled/restricted)
if [ "$SANDBOX" = "true" ]; then
  if [ "$SANDBOX_NET" = "true" ]; then
    BADGE_LIST+=("$(make_badge "${ICON_SANDBOX_NET}" "net-on" "95;135;95")")
  else
    BADGE_LIST+=("$(make_badge "${ICON_SANDBOX_NONET}" "net-off" "179;109;67")")
  fi
fi

# 7. Quotas (Dynamic 3P vs Gemini selection)
IS_3P=false
case "$MODEL_ID" in
  *[Cc][Ll][Aa][Uu][Dd][Ee]*|*[Gg][Pp][Tt]*|*[Aa][Nn][Tt][Hh][Rr][Oo][Pp][Ii][Cc]*|*[Oo][Pp][Ee][Nn][Aa][Ii]*|*[Oo]1*|*[Oo]3*|*3[Pp]*)
    IS_3P=true
    ;;
esac

Q_5H="-1"; Q_WK="-1"; Q_5H_R="-1"; Q_WK_R="-1"
if [ "$IS_3P" = true ]; then
  if { [ -n "$TP_5H" ] && [ "$TP_5H" != "-1" ]; } || { [ -n "$TP_WK" ] && [ "$TP_WK" != "-1" ]; }; then
    Q_5H="$TP_5H"; Q_WK="$TP_WK"; Q_5H_R="$TP_5H_RESET"; Q_WK_R="$TP_WK_RESET"
  elif { [ -n "$GEMINI_5H" ] && [ "$GEMINI_5H" != "-1" ]; } || { [ -n "$GEMINI_WK" ] && [ "$GEMINI_WK" != "-1" ]; }; then
    Q_5H="$GEMINI_5H"; Q_WK="$GEMINI_WK"; Q_5H_R="$GEMINI_5H_RESET"; Q_WK_R="$GEMINI_WK_RESET"
  fi
else
  if { [ -n "$GEMINI_5H" ] && [ "$GEMINI_5H" != "-1" ]; } || { [ -n "$GEMINI_WK" ] && [ "$GEMINI_WK" != "-1" ]; }; then
    Q_5H="$GEMINI_5H"; Q_WK="$GEMINI_WK"; Q_5H_R="$GEMINI_5H_RESET"; Q_WK_R="$GEMINI_WK_RESET"
  elif { [ -n "$TP_5H" ] && [ "$TP_5H" != "-1" ]; } || { [ -n "$TP_WK" ] && [ "$TP_WK" != "-1" ]; }; then
    Q_5H="$TP_5H"; Q_WK="$TP_WK"; Q_5H_R="$TP_5H_RESET"; Q_WK_R="$TP_WK_RESET"
  fi
fi

if [ "${Q_5H_R:- -1}" -gt 0 ] 2>/dev/null; then
  Q_5H_R=$(_tick_countdown "$Q_5H_R" "/tmp/agy_quota_5h_reset")
fi
if [ "${Q_WK_R:- -1}" -gt 0 ] 2>/dev/null; then
  Q_WK_R=$(_tick_countdown "$Q_WK_R" "/tmp/agy_quota_wk_reset")
fi

if [ -n "$Q_5H" ] && [ "$Q_5H" != "-1" ]; then
  qb="$(make_quota_bar "$Q_5H" "5H" "$Q_5H_R")"
  [ -n "$qb" ] && BADGE_LIST+=("$qb")
fi
if [ "$COLS" -ge 95 ] 2>/dev/null && [ -n "$Q_WK" ] && [ "$Q_WK" != "-1" ]; then
  qb="$(make_quota_bar "$Q_WK" "7D" "$Q_WK_R")"
  [ -n "$qb" ] && BADGE_LIST+=("$qb")
fi

# ─── Intelligent Multi-Line Packing ──────────────────────────────────────────
line1_vis=$(visible_len "$LINE1")

badges_vis=0
badges_joined=""
for ((i = 0; i < ${#BADGE_LIST[@]}; i++)); do
  b="${BADGE_LIST[i]}"
  [ -z "$b" ] && continue
  bv=$(visible_len "$b")
  if [ "$badges_vis" -eq 0 ]; then
    badges_vis=$bv
    badges_joined="$b"
  else
    badges_vis=$(( badges_vis + 3 + bv ))
    badges_joined="${badges_joined} \033[38;2;102;102;102m│\033[0m ${b}"
  fi
done

max_w=$(( COLS - 2 ))
[ "$max_w" -lt 35 ] && max_w=35

# 1. Single-Line Mode: If everything fits cleanly across terminal width
if [ $(( line1_vis + 3 + badges_vis )) -le "$max_w" ]; then
  if [ -n "$badges_joined" ]; then
    echo -e " ${LINE1} \033[38;2;102;102;102m│\033[0m ${badges_joined}"
  else
    echo -e " ${LINE1}"
  fi
  exit 0
fi

# 2. Multi-Line Split-Pane Mode: Wrap without truncation
if [ "$line1_vis" -le "$max_w" ]; then
  echo -e " ${LINE1}"
else
  curr_line=""
  curr_vis=0
  for seg in "${ACTIVE_SEGS[@]}"; do
    [ -z "$seg" ] && continue
    s_vis=$(visible_len "$seg")
    if [ -z "$curr_line" ]; then
      curr_line="$seg"
      curr_vis=$s_vis
    elif [ $(( curr_vis + 3 + s_vis )) -le "$max_w" ]; then
      curr_line="${curr_line} \033[38;2;102;102;102m│\033[0m ${seg}"
      curr_vis=$(( curr_vis + 3 + s_vis ))
    else
      echo -e " ${curr_line}"
      curr_line="$seg"
      curr_vis=$s_vis
    fi
  done
  [ -n "$curr_line" ] && echo -e " ${curr_line}"
fi

curr_line=""
curr_vis=0

for badge in "${BADGE_LIST[@]}"; do
  [ -z "$badge" ] && continue
  b_vis=$(visible_len "$badge")
  
  if [ -z "$curr_line" ]; then
    curr_line="$badge"
    curr_vis=$b_vis
  elif [ $(( curr_vis + 3 + b_vis )) -le "$max_w" ]; then
    curr_line="${curr_line} \033[38;2;102;102;102m│\033[0m ${badge}"
    curr_vis=$(( curr_vis + 3 + b_vis ))
  else
    echo -e " ${curr_line}"
    curr_line="$badge"
    curr_vis=$b_vis
  fi
done

if [ -n "$curr_line" ]; then
  echo -e " ${curr_line}"
fi
