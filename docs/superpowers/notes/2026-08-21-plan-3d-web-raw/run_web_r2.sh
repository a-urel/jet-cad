#!/bin/bash
# Usage: run_web_r2.sh ENTITIES BACKEND
# Runs the harness's RUN_R2 app-run mode on Chrome in profile mode, retrieves
# the printed block via Chrome DevTools Protocol (localStorage), and prints
# it. Cleans up its own Chrome/flutter run processes on exit.
set -u
ENTITIES="$1"
BACKEND="$2"
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike/apps/dev_harness_2d

pkill -9 -f "flutter run" 2>/dev/null
pkill -9 -f "Google Chrome" 2>/dev/null
sleep 1

LOG="/tmp/r2run.$$.$(date +%s).log"
: > "$LOG"
flutter run -d chrome --profile \
  --dart-define=RUN_R2=true --dart-define=TEXT=true \
  --dart-define=ENTITIES="$ENTITIES" --dart-define=BACKEND="$BACKEND" \
  > "$LOG" 2>&1 &
FPID=$!

# Wait for the CLI banner (compile + Chrome launch + connect).
for i in $(seq 1 60); do
  grep -q "Flutter run key commands" "$LOG" 2>/dev/null && break
  if ! kill -0 "$FPID" 2>/dev/null; then
    echo "FLUTTER RUN EXITED EARLY"
    cat "$LOG"
    exit 1
  fi
  sleep 2
done
if ! grep -q "Flutter run key commands" "$LOG" 2>/dev/null; then
  echo "TIMED OUT waiting for banner"
  cat "$LOG"
  kill -9 "$FPID" 2>/dev/null
  pkill -9 -f "Google Chrome" 2>/dev/null
  exit 1
fi

# Give Chrome a moment to fully register its CLI flags before we grep them.
sleep 3
PORT=$(ps aux | grep "Google Chrome" | grep -o -- "--remote-debugging-port=[0-9]*" | head -1 | cut -d= -f2)
if [ -z "$PORT" ]; then
  echo "NO CHROME REMOTE-DEBUGGING PORT FOUND"
  cat "$LOG"
  kill -9 "$FPID" 2>/dev/null
  pkill -9 -f "Google Chrome" 2>/dev/null
  exit 1
fi

PATH="$PATH:/Users/ahmeturel/Library/Python/3.9/bin" python3 /tmp/cdp_poll_generic.py "$PORT"
RC=$?

echo "--- flutter run log tail (diagnostics) ---"
tail -5 "$LOG"

kill -INT "$FPID" 2>/dev/null
sleep 2
kill -9 "$FPID" 2>/dev/null
pkill -9 -f "Google Chrome" 2>/dev/null
exit $RC
