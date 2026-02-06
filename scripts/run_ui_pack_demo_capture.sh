#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BINARY_PATH="${UI_PACK_DEMO_BINARY:-./build-debug/raylib-cpp-cmake-template}"
SCREENSHOT_PATH="${1:-${UI_PACK_DEMO_SCREENSHOT:-test_output/screenshots/crusenho_ui_pack_demo.png}}"
LOG_PATH="${UI_PACK_DEMO_LOG:-test_output/ui_pack_demo_run.log}"
FOCUS_DELAY="${UI_PACK_DEMO_OSA_DELAY_SEC:-0.8}"
STARTUP_DELAY="${UI_PACK_DEMO_STARTUP_SEC:-4.0}"
READY_TIMEOUT_SEC="${UI_PACK_DEMO_READY_TIMEOUT_SEC:-120}"
RENDER_SETTLE_DELAY="${UI_PACK_DEMO_RENDER_SETTLE_SEC:-1.2}"
TIMEOUT_SEC="${UI_PACK_DEMO_TIMEOUT_SEC:-20}"
MAX_CMDTAB_ATTEMPTS="${UI_PACK_DEMO_CMDTAB_ATTEMPTS:-20}"
APP_NAME_REGEX="${UI_PACK_DEMO_APP_REGEX:-raylib-cpp-cmake-template|Game}"
REQUIRE_FOCUS="${UI_PACK_DEMO_REQUIRE_FOCUS:-0}"
KILL_EXISTING="${UI_PACK_DEMO_KILL_EXISTING:-1}"

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "[ui-pack-demo] binary not found or not executable: $BINARY_PATH" >&2
  exit 1
fi

terminate_game() {
  local pid="$1"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  kill "$pid" 2>/dev/null || true
  (
    sleep "$TIMEOUT_SEC"
    if kill -0 "$pid" 2>/dev/null; then
      echo "[ui-pack-demo] process did not exit, force killing pid $pid" >&2
      kill -9 "$pid" 2>/dev/null || true
    fi
  ) &
  local killer_pid=$!
  wait "$pid" 2>/dev/null || true
  kill "$killer_pid" 2>/dev/null || true
  wait "$killer_pid" 2>/dev/null || true
}

cleanup_matching_game_processes() {
  local pids
  pids="$(pgrep -f "$BINARY_PATH" || true)"
  if [[ -z "${pids:-}" ]]; then
    return 0
  fi
  while IFS= read -r pid; do
    if [[ -n "$pid" ]]; then
      terminate_game "$pid"
    fi
  done <<< "$pids"
}

if [[ "$KILL_EXISTING" == "1" ]]; then
  existing_pids="$(pgrep -f "$BINARY_PATH" || true)"
  if [[ -n "${existing_pids:-}" ]]; then
    echo "[ui-pack-demo] stopping existing demo processes before launch"
    cleanup_matching_game_processes
  fi
fi

mkdir -p "$(dirname "$SCREENSHOT_PATH")"
mkdir -p "$(dirname "$LOG_PATH")"
rm -f "$SCREENSHOT_PATH"

echo "[ui-pack-demo] starting demo process"
echo "[ui-pack-demo] binary: $BINARY_PATH"
echo "[ui-pack-demo] screenshot: $SCREENSHOT_PATH"
echo "[ui-pack-demo] log: $LOG_PATH"

AUTO_TEST_UI_PACK=1 \
AUTO_EXIT_AFTER_UI_PACK_DEMO=0 \
"$BINARY_PATH" >"$LOG_PATH" 2>&1 &
GAME_PID=$!

sleep "$STARTUP_DELAY"

wait_for_log_line() {
  local pattern="$1"
  local timeout="$2"
  local start_ts now_ts
  start_ts="$(date +%s)"
  while true; do
    if grep -q "$pattern" "$LOG_PATH" 2>/dev/null; then
      return 0
    fi
    now_ts="$(date +%s)"
    if (( now_ts - start_ts > timeout )); then
      return 1
    fi
    if ! kill -0 "$GAME_PID" 2>/dev/null; then
      return 1
    fi
    sleep 0.2
  done
}

if ! wait_for_log_line "\\[UI_PACK_DEMO\\] READY_FOR_CAPTURE" "$READY_TIMEOUT_SEC"; then
  echo "[ui-pack-demo] did not receive READY_FOR_CAPTURE signal in log" >&2
  tail -n 60 "$LOG_PATH" >&2 || true
  terminate_game "$GAME_PID"
  exit 1
fi

if ! wait_for_log_line "Registered UI pack 'crusenho_flat'" "$READY_TIMEOUT_SEC"; then
  echo "[ui-pack-demo] UI pack did not report registration before capture" >&2
  tail -n 60 "$LOG_PATH" >&2 || true
  terminate_game "$GAME_PID"
  exit 1
fi

focused=0
if command -v osascript >/dev/null 2>&1; then
  echo "[ui-pack-demo] foregrounding game with osascript (command-tab loop)"
  unknown_focus_reads=0
  for ((i=1; i<=MAX_CMDTAB_ATTEMPTS; i++)); do
    FRONT_APP="$(osascript -e 'tell application \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null || true)"
    FRONT_PID="$(osascript -e 'tell application \"System Events\" to get unix id of first process whose frontmost is true' 2>/dev/null || true)"
    if [[ "$FRONT_PID" == "$GAME_PID" ]] || [[ "$FRONT_APP" =~ $APP_NAME_REGEX ]]; then
      echo "[ui-pack-demo] focused app: ${FRONT_APP:-<unknown>} (pid=${FRONT_PID:-?})"
      focused=1
      break
    fi

    if [[ -z "${FRONT_APP:-}" && -z "${FRONT_PID:-}" ]]; then
      unknown_focus_reads=$((unknown_focus_reads + 1))
      if (( unknown_focus_reads >= 3 )); then
        echo "[ui-pack-demo] osascript front-app query unavailable; proceeding with best-effort focus"
        break
      fi
    else
      unknown_focus_reads=0
    fi

    osascript -e 'tell application \"System Events\" to keystroke tab using {command down}' >/dev/null 2>&1 || true
    sleep "$FOCUS_DELAY"
  done
else
  echo "[ui-pack-demo] osascript unavailable; skipping window focus"
  focused=1
fi

if [[ "$focused" != "1" ]]; then
  FRONT_APP="$(osascript -e 'tell application \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null || true)"
  echo "[ui-pack-demo] warning: game focus could not be confirmed (front app: ${FRONT_APP:-unknown})" >&2
  if [[ "$REQUIRE_FOCUS" == "1" ]]; then
    echo "[ui-pack-demo] failing capture because focus is required (UI_PACK_DEMO_REQUIRE_FOCUS=1)" >&2
    terminate_game "$GAME_PID"
    exit 1
  fi
fi

sleep "$RENDER_SETTLE_DELAY"

if command -v screencapture >/dev/null 2>&1; then
  echo "[ui-pack-demo] capturing current display"
  screencapture -x "$SCREENSHOT_PATH"
else
  echo "[ui-pack-demo] screencapture unavailable" >&2
  terminate_game "$GAME_PID"
  exit 1
fi

# Shutdown game process.
terminate_game "$GAME_PID"
if [[ "$KILL_EXISTING" == "1" ]]; then
  cleanup_matching_game_processes
fi

if [[ ! -f "$SCREENSHOT_PATH" ]]; then
  echo "[ui-pack-demo] screenshot not created: $SCREENSHOT_PATH" >&2
  exit 1
fi

if [[ ! -s "$SCREENSHOT_PATH" ]]; then
  echo "[ui-pack-demo] screenshot file is empty: $SCREENSHOT_PATH" >&2
  exit 1
fi

echo "[ui-pack-demo] screenshot captured successfully"
echo "[ui-pack-demo] done"
