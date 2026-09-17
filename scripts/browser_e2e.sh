#!/usr/bin/env bash
set -Eeuo pipefail

session_name="disco-tutorial-e2e"
export CHROME_DEVTOOLS_AXI_SESSION="$session_name"

mkdir -p artifacts build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8877 --directory build/web >artifacts/browser-server.txt 2>&1 &
server_pid=$!

for _attempt in 1 2 3 4 5; do
  if curl --fail --silent http://127.0.0.1:8877/index.html >/dev/null; then
    break
  fi
  sleep 0.2
done
curl --fail --silent http://127.0.0.1:8877/index.html >/dev/null

cleanup() {
  kill "$server_pid" 2>/dev/null || true
  chrome-devtools-axi stop >/dev/null 2>&1 || true
}

capture_failure() {
  chrome-devtools-axi console >artifacts/browser-console.txt 2>&1 || true
  chrome-devtools-axi screenshot artifacts/browser-failure.png >/dev/null 2>&1 || true
}

trap 'status=$?; capture_failure; cleanup; exit $status' ERR
trap cleanup EXIT

chrome-devtools-axi start >/dev/null
chrome-devtools-axi open http://127.0.0.1:8877/index.html >/dev/null
chrome-devtools-axi resize 390 844 >/dev/null
sleep 4

click_canvas() {
  local x="$1"
  local y="$2"
  chrome-devtools-axi eval "() => { const c=document.querySelector('canvas'); const r=c.getBoundingClientRect(); const e={bubbles:true,clientX:r.left+${x},clientY:r.top+${y},button:0}; c.dispatchEvent(new MouseEvent('mousedown',e)); c.dispatchEvent(new MouseEvent('mouseup',e)); return window.discoBreakerState.stage_id; }" >/dev/null
  sleep 0.15
}

assert_state() {
  local expression="$1"
  chrome-devtools-axi eval "() => { if (!(${expression})) throw new Error('state assertion failed'); return JSON.stringify(window.discoBreakerState); }" >/dev/null
}

assert_state "window.discoBreakerState.stage_id === 'red_one_tap'"
chrome-devtools-axi screenshot artifacts/tutorial-stage-1.png >/dev/null
click_canvas 195 793
click_canvas 195 309
assert_state "window.discoBreakerState.result_visible"
click_canvas 195 793

click_canvas 195 793
click_canvas 195 309
click_canvas 195 309
assert_state "window.discoBreakerState.floor_dark"
click_canvas 195 793

click_canvas 195 793
click_canvas 195 309
click_canvas 195 309
click_canvas 195 309
click_canvas 195 793

click_canvas 195 793
assert_state "window.discoBreakerState.can_call_foreman"
click_canvas 195 793
assert_state "window.discoBreakerState.inspection.safe"
click_canvas 195 793

click_canvas 195 793
assert_state "window.discoBreakerState.inspection.red_crossing && !window.discoBreakerState.inspection.blue_crossing"
chrome-devtools-axi screenshot artifacts/tutorial-crossing-trap.png >/dev/null
click_canvas 195 793

click_canvas 195 793
click_canvas 195 326
click_canvas 263 191
click_canvas 263 191
click_canvas 127 461
assert_state "window.discoBreakerState.can_call_foreman"
click_canvas 195 793
assert_state "window.discoBreakerState.inspection.safe"
chrome-devtools-axi screenshot artifacts/tutorial-graduation.png >/dev/null
click_canvas 195 793
assert_state "window.discoBreakerState.finished"

chrome-devtools-axi console --type error >artifacts/browser-console.txt
printf 'PASS: browser completed all six tutorial stages\n'
