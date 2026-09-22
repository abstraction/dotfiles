#!/bin/bash
# statusline.sh - Minimal & Responsive Telemetry Statusline for Antigravity CLI
# Built with theme-adaptive ANSI colors, accurate context telemetry, and responsive wrapping

set -euo pipefail
export LC_NUMERIC=C

# ─── Color Palette (Theme-Harmonized ANSI) ───────────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_MUTED="\033[90m"        # Theme muted/comment gray (dividers, secondary timers, limits)
C_PRIMARY="\033[0m"       # Theme default foreground (model, cwd, healthy metrics)
C_SUCCESS="\033[32m"      # Theme green (READY state)
C_INFO="\033[36m"         # Theme cyan/aqua (WORKING state)
C_THINK="\033[35m"        # Theme purple/magenta (THINKING state)
C_WARN="\033[33m"         # Theme yellow/amber (TOOL state, quota < 20%, dirty git)
C_DANGER="\033[31m"       # Theme red/coral (critical quota < 5%, high context >= 80%)
DIVIDER="${C_MUTED}│${C_RESET}"

for arg in "$@"; do
  if [ "$arg" = "--version" ] || [ "$arg" = "-v" ]; then
    echo "Antigravity CLI Statusline v0.4.0"
    exit 0
  fi
  if [ "$arg" = "--legend" ] || [ "$arg" = "-l" ] || [ "$arg" = "legend" ]; then
    echo -e "${C_INFO}${C_BOLD}󰓅 Minimal Omarchy Statusline Legend (v0.4.0)${C_RESET}"
    echo -e "A high-density, responsive telemetry statusline that dynamically adapts to split panes."
    echo -e ""
    echo -e "${C_BOLD}LAYOUT & RESPONSIVENESS:${C_RESET}"
    echo -e "  - ${C_BOLD}Wide terminals (>= 130 cols):${C_RESET} All segments render on a single, unified flat line."
    echo -e "  - ${C_BOLD}Split panes (< 130 cols):${C_RESET} Intelligently wraps into 2 (or 3) balanced lines without clipping."
    echo -e "  - ${C_BOLD}Narrow panes (< 75 cols):${C_RESET} Compacts paths to basenames and shortens model names."
    echo -e ""
    echo -e "${C_BOLD}COMPONENTS & METRICS:${C_RESET}"
    echo -e "  ${C_SUCCESS}${C_BOLD} READY${C_RESET} / ${C_INFO}${C_BOLD} WORKING${C_RESET}   Agent state (READY, WORKING, THINKING, TOOL)."
    echo -e "  ${C_PRIMARY}${C_BOLD} main${C_WARN}*${C_RESET}                   Git branch with dirty indicator (*)."
    echo -e "  ${C_PRIMARY} 3.8 Flash ${C_MUTED}[H]${C_RESET}           Active model with compact effort badge ([H], [M], [L], [T])."
    echo -e "  ${C_PRIMARY} ~/my/think/temp${C_RESET}        Current working directory."
    echo -e "  ${C_MUTED}󱍏${C_RESET} 18.6% ${C_MUTED}(195K)${C_RESET}          Active conversation context window usage and total token count."
    echo -e "  ${C_INFO} 2${C_RESET}  ${C_THINK}󱙺 1${C_RESET}  ${C_WARN} 1${C_RESET}         Progressive disclosure: artifacts, subagents, and tasks"
    echo -e "                        appear only when active (> 0). Zero-counts are omitted."
    echo -e "  ${C_BOLD}G:${C_RESET} 95%${C_MUTED}/${C_RESET}${C_WARN}18%${C_RESET} ${C_MUTED} 4h/1d${C_RESET} ${DIVIDER} ${C_MUTED}C:${C_RESET} 54%${C_MUTED}/${C_RESET}57% ${C_MUTED} 4h/4d${C_RESET}"
    echo -e "                        Dual quota telemetry: Gemini (G:) and Claude/3P (C:) models,"
    echo -e "                        displaying short (5h) / weekly (7d) remaining percentages"
    echo -e "                        and parallel reset deadlines (). Active model is bolded."
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
    (if (.quota["gemini-5h"] // .quota["gemini_5h"]).remaining_fraction != null then (((.quota["gemini-5h"] // .quota["gemini_5h"]).remaining_fraction * 1000 | round) / 10) else -1 end),
    (if (.quota["gemini-weekly"] // .quota["gemini_weekly"] // .quota["gemini-7d"]).remaining_fraction != null then (((.quota["gemini-weekly"] // .quota["gemini_weekly"] // .quota["gemini-7d"]).remaining_fraction * 1000 | round) / 10) else -1 end),
    (if (.quota["3p-5h"] // .quota["3p_5h"] // .quota["claude-5h"] // .quota["claude_5h"]).remaining_fraction != null then (((.quota["3p-5h"] // .quota["3p_5h"] // .quota["claude-5h"] // .quota["claude_5h"]).remaining_fraction * 1000 | round) / 10) else -1 end),
    (if (.quota["3p-weekly"] // .quota["3p_weekly"] // .quota["3p-7d"] // .quota["claude-weekly"] // .quota["claude_7d"]).remaining_fraction != null then (((.quota["3p-weekly"] // .quota["3p_weekly"] // .quota["3p-7d"] // .quota["claude-weekly"] // .quota["claude_7d"]).remaining_fraction * 1000 | round) / 10) else -1 end),
    ((.quota["gemini-5h"] // .quota["gemini_5h"]).reset_in_seconds // -1),
    ((.quota["gemini-weekly"] // .quota["gemini_weekly"] // .quota["gemini-7d"]).reset_in_seconds // -1),
    ((.quota["3p-5h"] // .quota["3p_5h"] // .quota["claude-5h"] // .quota["claude_5h"]).reset_in_seconds // -1),
    ((.quota["3p-weekly"] // .quota["3p_weekly"] // .quota["3p-7d"] // .quota["claude-weekly"] // .quota["claude_7d"]).reset_in_seconds // -1),
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

format_compact_time() {
  local sec=$1
  if [ -z "$sec" ] || [ "$sec" -le 0 ] 2>/dev/null; then echo -n ""; return; fi
  local days=$((sec / 86400))
  local rem=$((sec % 86400))
  local hours=$((rem / 3600))
  rem=$((rem % 3600))
  local mins=$((rem / 60))

  if [ "$days" -gt 0 ]; then
    echo -n "${days}d"
  elif [ "$hours" -gt 0 ]; then
    echo -n "${hours}h"
  elif [ "$mins" -gt 0 ]; then
    echo -n "${mins}m"
  else
    echo -n "<1m"
  fi
}

format_quota_val() {
  local val="$1"
  if [ -z "$val" ] || [ "$val" = "-1" ]; then return; fi
  local val_int=${val%.*}; val_int=${val_int:-0}
  local color="${C_PRIMARY}"
  if [ "$val_int" -lt 5 ]; then
    color="${C_DANGER}"
  elif [ "$val_int" -lt 20 ]; then
    color="${C_WARN}"
  fi
  local fmt
  if [ "$val_int" -lt 10 ] && [[ "$val" =~ \. ]]; then
    fmt=$(LC_NUMERIC=C printf "%.1f" "$val" 2>/dev/null || echo "$val")
  else
    fmt=$(LC_NUMERIC=C printf "%.0f" "$val" 2>/dev/null || echo "$val_int")
  fi
  echo -n "${color}${fmt}%${C_RESET}"
}

make_model_quota_badge() {
  local label="$1"
  local s_val="$2"
  local w_val="$3"
  local s_reset="$4"
  local w_reset="$5"
  local is_active="$6"
  local cols="${7:-80}"

  if { [ -z "$s_val" ] || [ "$s_val" = "-1" ]; } && { [ -z "$w_val" ] || [ "$w_val" = "-1" ]; }; then
    return
  fi

  local label_str
  if [ "$is_active" = "true" ]; then
    label_str="${C_BOLD}${label}:${C_RESET}"
  else
    label_str="${C_MUTED}${label}:${C_RESET}"
  fi

  local slash="${C_MUTED}/${C_RESET}"
  local val_str=""
  local s_fmt; s_fmt=$(format_quota_val "$s_val")
  local w_fmt; w_fmt=$(format_quota_val "$w_val")

  if [ -n "$s_fmt" ] && [ -n "$w_fmt" ]; then
    val_str="${s_fmt}${slash}${w_fmt}"
  elif [ -n "$s_fmt" ]; then
    val_str="${s_fmt}"
  elif [ -n "$w_fmt" ]; then
    val_str="${C_MUTED}--${C_RESET}${slash}${w_fmt}"
  fi

  local reset_str=""
  local s_int=${s_val%.*}; s_int=${s_int:- -1}
  local w_int=${w_val%.*}; w_int=${w_int:- -1}

  local s_time=""
  local w_time=""
  if [ -n "$s_reset" ] && [ "$s_reset" -gt 0 ] 2>/dev/null && [ "$s_int" -ge 0 ] && [ "$s_int" -lt 100 ]; then
    s_time=$(format_compact_time "$s_reset")
  fi
  if [ -n "$w_reset" ] && [ "$w_reset" -gt 0 ] 2>/dev/null && [ "$w_int" -ge 0 ] && [ "$w_int" -lt 100 ]; then
    w_time=$(format_compact_time "$w_reset")
  fi

  local show_reset=false
  if [ "$s_int" -ge 0 ] && [ "$s_int" -lt 20 ]; then
    show_reset=true
  elif [ "$w_int" -ge 0 ] && [ "$w_int" -lt 20 ]; then
    show_reset=true
  elif [ "$cols" -ge 75 ] 2>/dev/null && { [ "$s_int" -lt 50 ] || [ "$w_int" -lt 50 ]; }; then
    show_reset=true
  elif [ "$cols" -ge 105 ] 2>/dev/null && { [ -n "$s_time" ] || [ -n "$w_time" ]; }; then
    show_reset=true
  fi

  if [ "$show_reset" = "true" ] && { [ -n "$s_time" ] || [ -n "$w_time" ]; }; then
    local time_pair=""
    if [ -n "$s_time" ] && [ -n "$w_time" ]; then
      time_pair="${s_time}/${w_time}"
    elif [ -n "$s_time" ]; then
      time_pair="${s_time}"
    elif [ -n "$w_time" ]; then
      time_pair="--/${w_time}"
    fi

    reset_str=" ${C_MUTED} ${time_pair}${C_RESET}"
  fi

  echo -n "${label_str} ${val_str}${reset_str}"
}

make_badge() {
  local icon="$1"
  local val="$2"
  local color="${3:-$C_PRIMARY}"
  echo -n "${color}${icon} ${val}${C_RESET}"
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
    if [ "$d" -eq 0 ] || [ "$m" -ge 10 ]; then
      echo "${m}M"
    else
      echo "${m}.${d}M"
    fi
  elif [ "$num" -ge 100000 ] 2>/dev/null; then
    local k=$(( (num + 500) / 1000 ))
    echo "${k}K"
  elif [ "$num" -ge 1000 ] 2>/dev/null; then
    local k=$(( num / 1000 ))
    local d=$(( (num % 1000) / 100 ))
    if [ "$d" -eq 0 ] || [ "$k" -ge 10 ]; then
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

# ─── Icons ───────────────────────────────────────────────────────────────────
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
ICON_CLOCK=""
ICON_BOLT="󱐋"

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
RAW_MODEL="${MODEL_NAME:-$MODEL_ID}"

EFFORT_TAG=""
case "${RAW_MODEL,,}" in
  *high*)  EFFORT_TAG="[H]" ;;
  *med*)   EFFORT_TAG="[M]" ;;
  *low*)   EFFORT_TAG="[L]" ;;
  *think*) EFFORT_TAG="[T]" ;;
  *\(*\)*)
    inside="${RAW_MODEL#*\(}"
    inside="${inside%%\)*}"
    if [ -n "$inside" ]; then
      first_char="${inside:0:1}"
      EFFORT_TAG="[${first_char^^}]"
    fi
    ;;
esac

MODEL_DISP="$RAW_MODEL"
MODEL_DISP="${MODEL_DISP#Gemini }"
MODEL_DISP="${MODEL_DISP#Claude }"
MODEL_DISP="${MODEL_DISP#GPT-OSS }"
MODEL_DISP="${MODEL_DISP%% (*}"
MODEL_DISP="${MODEL_DISP%-high}"
MODEL_DISP="${MODEL_DISP%-medium}"
MODEL_DISP="${MODEL_DISP%-med}"
MODEL_DISP="${MODEL_DISP%-low}"

if [ "$COLS" -lt 70 ] 2>/dev/null; then
  MODEL_DISP="${MODEL_DISP%% *}"
fi

if [ -n "$EFFORT_TAG" ]; then
  MODEL_SEG="${C_PRIMARY}${ICON_MODEL} ${MODEL_DISP} ${C_MUTED}${EFFORT_TAG}${C_RESET}"
else
  MODEL_SEG="${C_PRIMARY}${ICON_MODEL} ${MODEL_DISP}${C_RESET}"
fi

# ─── Assemble LINE1 (Identity & State) ───────────────────────────────────────
ACTIVE_SEGS=()
case "$STATE" in
  idle)     ACTIVE_SEGS+=("${C_SUCCESS}${C_BOLD}${ICON_READY} READY${C_RESET}") ;;
  thinking) ACTIVE_SEGS+=("${C_THINK}${C_BOLD}${ICON_THINKING} THINKING${C_RESET}") ;;
  working)  ACTIVE_SEGS+=("${C_INFO}${C_BOLD}${ICON_WORKING} WORKING${C_RESET}") ;;
  tool_use) ACTIVE_SEGS+=("${C_WARN}${C_BOLD}${ICON_TOOL} TOOL${C_RESET}") ;;
  *)        ACTIVE_SEGS+=("${C_PRIMARY}${C_BOLD}${ICON_STATE_UNKNOWN} ${STATE^^}${C_RESET}") ;;
esac

if [ -n "$VCS_BRANCH" ]; then
  if [ "$VCS_DIRTY" = "true" ]; then
    ACTIVE_SEGS+=("${C_PRIMARY}${C_BOLD}${ICON_VCS} ${VCS_BRANCH}${C_WARN}*${C_RESET}")
  else
    ACTIVE_SEGS+=("${C_PRIMARY}${C_BOLD}${ICON_VCS} ${VCS_BRANCH}${C_RESET}")
  fi
fi

if [ -n "$MODEL_DISP" ]; then
  ACTIVE_SEGS+=("$MODEL_SEG")
fi

CWD_SHORT=$(shorten_path "$CWD")
if [ -n "$CWD_SHORT" ]; then
  ACTIVE_SEGS+=("${C_PRIMARY}${ICON_DIR} ${CWD_SHORT}${C_RESET}")
fi

LINE1=""
for ((i = 0; i < ${#ACTIVE_SEGS[@]}; i++)); do
  if [ "$i" -gt 0 ]; then
    LINE1="${LINE1} ${DIVIDER} ${ACTIVE_SEGS[i]}"
  else
    LINE1="${ACTIVE_SEGS[i]}"
  fi
done

# ─── Assemble Badges (Progressive Disclosure & Accurate Context) ─────────────
BADGE_LIST=()

# 1. Context Window Usage (Accurate conversation context & tokens)
PCT_FMT=$(LC_NUMERIC=C printf "%.1f" "$USED_PCT" 2>/dev/null || echo "0.0")
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}
if [ -n "$USED_PCT" ]; then
  ctx_color="${C_PRIMARY}"
  if [ "$PCT_INT" -ge 80 ]; then
    ctx_color="${C_DANGER}"
  elif [ "$PCT_INT" -ge 50 ]; then
    ctx_color="${C_WARN}"
  fi

  ctx_used_fmt=$(human_format "$CTX_USED")
  ctx_limit_fmt=$(human_format "$CTX_LIMIT")

  ctx_detail=""
  if [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
    if [ "$COLS" -ge 120 ] 2>/dev/null && [ "$CTX_LIMIT" -gt 0 ] 2>/dev/null; then
      ctx_detail=" ${C_MUTED}(${ctx_used_fmt}/${ctx_limit_fmt})${C_RESET}"
    elif [ "$COLS" -ge 85 ] 2>/dev/null; then
      ctx_detail=" ${C_MUTED}(${ctx_used_fmt})${C_RESET}"
    fi
  fi

  BADGE_LIST+=("${C_MUTED}${ICON_CONTEXT_BAR}${C_RESET} ${ctx_color}${PCT_FMT}%${C_RESET}${ctx_detail}")
fi

# 2. Artifacts Counter (Progressive disclosure: ONLY if > 0)
if [ "$ARTIFACTS" -gt 0 ] 2>/dev/null; then
  BADGE_LIST+=("$(make_badge "${ICON_ARTIFACTS}" "${ARTIFACTS}" "${C_INFO}")")
fi

# 3. Subagents Counter (Progressive disclosure: ONLY if > 0)
if [ "$SUBAGENTS" -gt 0 ] 2>/dev/null; then
  BADGE_LIST+=("$(make_badge "${ICON_SUBAGENTS}" "${SUBAGENTS}" "${C_THINK}")")
fi

# 4. Background Tasks Counter (Progressive disclosure: ONLY if > 0)
if [ "$BG_TASKS" -gt 0 ] 2>/dev/null; then
  BADGE_LIST+=("$(make_badge "${ICON_TASKS}" "${BG_TASKS}" "${C_WARN}")")
fi

# 5. Sandbox Status (Progressive disclosure: ONLY if enabled/restricted)
if [ "$SANDBOX" = "true" ]; then
  if [ "$SANDBOX_NET" = "true" ]; then
    BADGE_LIST+=("$(make_badge "${ICON_SANDBOX_NET}" "net-on" "${C_SUCCESS}")")
  else
    BADGE_LIST+=("$(make_badge "${ICON_SANDBOX_NONET}" "net-off" "${C_WARN}")")
  fi
fi

# 6. Quotas (Dual Gemini & Claude/3P trackers)
IS_GEMINI=false
IS_CLAUDE=false
case "$MODEL_ID" in
  *[Cc][Ll][Aa][Uu][Dd][Ee]*|*[Aa][Nn][Tt][Hh][Rr][Oo][Pp][Ii][Cc]*|*[Gg][Pp][Tt]*|*[Oo][Pp][Ee][Nn][Aa][Ii]*|*[Oo]1*|*[Oo]3*|*3[Pp]*)
    IS_CLAUDE=true
    ;;
  *[Gg][Ee][Mm][Ii][Nn][Ii]*|*)
    IS_GEMINI=true
    ;;
esac

LABEL_3P="C"
case "$MODEL_ID" in
  *[Gg][Pp][Tt]*|*[Oo][Pp][Ee][Nn][Aa][Ii]*|*[Oo]1*|*[Oo]3*)
    LABEL_3P="O"
    ;;
esac

if [ "${GEMINI_5H_RESET:- -1}" -gt 0 ] 2>/dev/null; then
  GEMINI_5H_RESET=$(_tick_countdown "$GEMINI_5H_RESET" "/tmp/agy_quota_gemini_5h_reset")
fi
if [ "${GEMINI_WK_RESET:- -1}" -gt 0 ] 2>/dev/null; then
  GEMINI_WK_RESET=$(_tick_countdown "$GEMINI_WK_RESET" "/tmp/agy_quota_gemini_wk_reset")
fi
if [ "${TP_5H_RESET:- -1}" -gt 0 ] 2>/dev/null; then
  TP_5H_RESET=$(_tick_countdown "$TP_5H_RESET" "/tmp/agy_quota_3p_5h_reset")
fi
if [ "${TP_WK_RESET:- -1}" -gt 0 ] 2>/dev/null; then
  TP_WK_RESET=$(_tick_countdown "$TP_WK_RESET" "/tmp/agy_quota_3p_wk_reset")
fi

GEMINI_BADGE=$(make_model_quota_badge "G" "$GEMINI_5H" "$GEMINI_WK" "$GEMINI_5H_RESET" "$GEMINI_WK_RESET" "$IS_GEMINI" "$COLS")
CLAUDE_BADGE=$(make_model_quota_badge "$LABEL_3P" "$TP_5H" "$TP_WK" "$TP_5H_RESET" "$TP_WK_RESET" "$IS_CLAUDE" "$COLS")

if [ -n "$GEMINI_BADGE" ]; then
  BADGE_LIST+=("$GEMINI_BADGE")
fi
if [ -n "$CLAUDE_BADGE" ]; then
  BADGE_LIST+=("$CLAUDE_BADGE")
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
    badges_joined="${badges_joined} ${DIVIDER} ${b}"
  fi
done

max_w=$(( COLS - 2 ))
[ "$max_w" -lt 35 ] && max_w=35

# 1. Single-Line Mode: If everything fits cleanly across terminal width
if [ $(( line1_vis + 3 + badges_vis )) -le "$max_w" ]; then
  if [ -n "$badges_joined" ]; then
    echo -e " ${LINE1} ${DIVIDER} ${badges_joined}"
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
      curr_line="${curr_line} ${DIVIDER} ${seg}"
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
    curr_line="${curr_line} ${DIVIDER} ${badge}"
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
