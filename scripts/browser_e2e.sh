#!/usr/bin/env bash
set -Eeuo pipefail

session_name="disco-tutorial-e2e"
export CHROME_DEVTOOLS_AXI_SESSION="$session_name"

mkdir -p artifacts build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8877 --bind 127.0.0.1 --directory build/web >artifacts/browser-server.txt 2>&1 &
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

inventory_file="artifacts/tutorial-browser-state-inventory.jsonl"
action_file="artifacts/tutorial-browser-action-trace.jsonl"
: >"$inventory_file"
: >"$action_file"
captures=()
run_name="graduation"

axi_object() {
  local expression="$1"
  chrome-devtools-axi eval "$expression" | sed -n 's/^result: //p' | jq -c -r 'fromjson'
}

record_action() {
  local action="$1"
  axi_object "() => ({run:'${run_name}',action:'${action}',state:window.discoBreakerState})" >>"$action_file"
}

capture_state() {
  local sequence="$1"
  local name="$2"
  local path="artifacts/tutorial-audit-${sequence}-${name}.png"
  chrome-devtools-axi screenshot "$path" >/dev/null
  captures+=("$path")
  axi_object "() => ({run:'${run_name}',capture:'${sequence}-${name}',viewport:{width:innerWidth,height:innerHeight},state:window.discoBreakerState})" >>"$inventory_file"
}

click_canvas() {
  local x="$1"
  local y="$2"
  local action="$3"
  local count="${4:-1}"
  chrome-devtools-axi eval "async () => { const c=document.querySelector('canvas'); const r=c.getBoundingClientRect(); for(let i=0;i<${count};i++){ const e={bubbles:true,clientX:r.left+${x},clientY:r.top+${y},button:0}; c.dispatchEvent(new MouseEvent('mousedown',e)); c.dispatchEvent(new MouseEvent('mouseup',e)); await new Promise(resolve => setTimeout(resolve,50)); } return true; }" >/dev/null
  sleep 0.15
  record_action "$action"
}

assert_state() {
  local expression="$1"
  chrome-devtools-axi eval "() => { if (!(${expression})) throw new Error('state assertion failed'); return JSON.stringify(window.discoBreakerState); }" >/dev/null
}

cycle_grid_3x3() {
  local stage="$1"
  local xs=(100 195 290)
  local ys=(214 309 404)
  for row in 0 1 2; do
    for column in 0 1 2; do
      if [[ "$stage" != "stage4" && "$stage" != "stage7" && "$row" == "1" && "$column" == "1" ]]; then
        continue
      fi
      click_canvas "${xs[$column]}" "${ys[$row]}" "${stage}-cycle-box-${row}-${column}" 4
    done
  done
}

assert_state "window.discoBreakerState.screen === 'title' && !window.discoBreakerState.campaign_available"
click_canvas 195 775 title-enter-tutorial
sleep 0.3
assert_state "window.discoBreakerState.screen === 'tutorial' && window.discoBreakerState.stage_id === 'red_one_tap'"
capture_state 01 stage1-intro-dialogue
chrome-devtools-axi screenshot artifacts/tutorial-stage-1.png >/dev/null
click_canvas 195 793 stage1-confirm-dialogue
capture_state 02 stage1-pre-action
cycle_grid_3x3 stage1
assert_state "window.discoBreakerState.corrections.every(value => value === 0)"
click_canvas 195 309 stage1-target-red
assert_state "window.discoBreakerState.result_visible"
capture_state 03 stage1-success
click_canvas 195 793 stage1-next

capture_state 04 stage2-intro-dialogue
click_canvas 195 793 stage2-confirm-dialogue
capture_state 05 stage2-pre-action
cycle_grid_3x3 stage2
assert_state "window.discoBreakerState.corrections.every(value => value === 0)"
click_canvas 195 309 stage2-cycle-red
capture_state 06 stage2-intermediate-red
click_canvas 195 309 stage2-cycle-blue
assert_state "window.discoBreakerState.floor_dark"
capture_state 07 stage2-success-blue
click_canvas 195 793 stage2-next

capture_state 08 stage3-intro-dialogue
chrome-devtools-axi screenshot artifacts/tutorial-dialogue-wrap.png >/dev/null
click_canvas 195 793 stage3-confirm-dialogue
capture_state 09 stage3-pre-action
cycle_grid_3x3 stage3
assert_state "window.discoBreakerState.corrections.every(value => value === 0)"
click_canvas 195 309 stage3-cycle-red
capture_state 10 stage3-intermediate-red
click_canvas 195 309 stage3-cycle-blue
capture_state 11 stage3-intermediate-blue
click_canvas 195 309 stage3-cycle-both
capture_state 12 stage3-success-both
click_canvas 195 793 stage3-next

capture_state 13 stage4-intro-dialogue
click_canvas 195 793 stage4-confirm-dialogue
assert_state "window.discoBreakerState.can_call_foreman"
capture_state 14 stage4-inspection-ready
cycle_grid_3x3 stage4
assert_state "window.discoBreakerState.can_call_foreman"
click_canvas 195 793 stage4-call-foreman
assert_state "window.discoBreakerState.inspection.safe"
capture_state 15 stage4-inspection-passed
chrome-devtools-axi screenshot artifacts/tutorial-inspection-dialogue.png >/dev/null
click_canvas 195 793 stage4-next

capture_state 16 stage5-intro-dialogue
click_canvas 195 793 stage5-confirm-and-inspect
assert_state "window.discoBreakerState.inspection.red_crossing && !window.discoBreakerState.inspection.blue_crossing"
capture_state 17 stage5-failure-witness
chrome-devtools-axi screenshot artifacts/tutorial-crossing-trap.png >/dev/null
click_canvas 195 793 stage5-next

assert_state "window.discoBreakerState.stage === 6 && window.discoBreakerState.stage_count === 7 && window.discoBreakerState.lit_red.length === 1 && window.discoBreakerState.lit_blue.length === 0"
capture_state 17a stage6-red-intro
click_canvas 195 793 stage6-red-confirm
capture_state 17b stage6-red-ready
click_canvas 100 214 stage6-red-edge
assert_state "window.discoBreakerState.floor_dark && window.discoBreakerState.inspection.safe"
capture_state 17c stage6-red-cleared
click_canvas 195 793 stage6-try-blue
assert_state "window.discoBreakerState.stage === 6 && window.discoBreakerState.boundary_phase === 1 && window.discoBreakerState.lit_blue.length === 1 && window.discoBreakerState.lit_red.length === 0"
capture_state 17d stage6-blue-intro
click_canvas 195 793 stage6-blue-confirm
capture_state 17e stage6-blue-ready
click_canvas 290 214 stage6-blue-intermediate-red
assert_state "!window.discoBreakerState.floor_dark && !window.discoBreakerState.result_visible"
capture_state 17f stage6-blue-intermediate-red
click_canvas 290 214 stage6-blue-edge
assert_state "window.discoBreakerState.floor_dark && window.discoBreakerState.inspection.safe"
capture_state 17g stage6-blue-cleared
click_canvas 195 793 stage6-next

capture_state 18 stage7-intro-dialogue
click_canvas 195 793 stage7-confirm-dialogue
capture_state 19 stage7-pre-action-call-disabled
click_canvas 195 793 stage7-disabled-call
assert_state "!window.discoBreakerState.can_call_foreman && window.discoBreakerState.last_action.action === 'confirm_dialogue'"
cycle_grid_3x3 stage7
assert_state "window.discoBreakerState.grid_size === 3 && window.discoBreakerState.corrections.every(value => value === 0)"
capture_state 19a two-red-flickers-before
click_canvas 195 309 stage7-regression-center-red
assert_state "window.discoBreakerState.lit_red.length === 0 && window.discoBreakerState.lit_blue.length > 0"
capture_state 19b two-red-flickers-after
click_canvas 195 309 stage7-regression-center-reset 3
click_canvas 195 309 stage7-place-center-red
capture_state 20 stage7-after-center-red
click_canvas 290 214 stage7-corner-cycle-red
capture_state 21 stage7-corner-intermediate-red
click_canvas 290 214 stage7-corner-cycle-blue
capture_state 22 stage7-after-corner-blue
assert_state "window.discoBreakerState.can_call_foreman"
capture_state 23 stage7-inspection-ready
click_canvas 195 793 stage7-call-foreman
assert_state "window.discoBreakerState.inspection.safe"
capture_state 24 stage7-graduation-passed
chrome-devtools-axi screenshot artifacts/tutorial-graduation.png >/dev/null
click_canvas 195 793 stage7-complete
assert_state "window.discoBreakerState.finished"
capture_state 25 tutorial-complete
click_canvas 195 793 graduation-run-replay
assert_state "window.discoBreakerState.stage_id === 'red_one_tap' && !window.discoBreakerState.finished"

# A second deterministic run exercises the optional skip button without
# replacing the full graduation path above.
run_name="optional-skip"
chrome-devtools-axi open http://127.0.0.1:8877/index.html >/dev/null
sleep 4
click_canvas 195 775 skip-run-title-enter
sleep 0.3
click_canvas 195 793 skip-run-stage1-confirm
click_canvas 195 309 skip-run-stage1-solve
click_canvas 195 793 skip-run-stage1-next
click_canvas 195 793 skip-run-stage2-confirm
click_canvas 195 309 skip-run-stage2-red
click_canvas 195 309 skip-run-stage2-blue
click_canvas 195 793 skip-run-stage2-next
click_canvas 195 793 skip-run-stage3-confirm
click_canvas 195 309 skip-run-stage3-red
click_canvas 195 309 skip-run-stage3-blue
click_canvas 195 309 skip-run-stage3-both
click_canvas 195 793 skip-run-stage3-next
click_canvas 195 793 skip-run-stage4-confirm
click_canvas 195 793 skip-run-stage4-call
click_canvas 195 793 skip-run-stage4-next
click_canvas 195 793 skip-run-stage5-confirm
click_canvas 195 793 skip-run-stage5-next
click_canvas 195 793 skip-run-stage7-confirm
assert_state "window.discoBreakerState.stage_id === 'boundary_single'"
click_canvas 100 214 skip-run-stage6-red
click_canvas 195 793 skip-run-stage6-try-blue
click_canvas 195 793 skip-run-stage6-blue-confirm
click_canvas 290 214 skip-run-stage6-blue 2
click_canvas 195 793 skip-run-stage6-next
click_canvas 195 793 skip-run-stage7-confirm-review
assert_state "window.discoBreakerState.stage_id === 'graduation_3x3' && !window.discoBreakerState.finished"
click_canvas 195 735 stage7-skip-optional
assert_state "window.discoBreakerState.finished"
capture_state 26 optional-graduation-skipped
click_canvas 195 793 optional-skip-run-replay
assert_state "window.discoBreakerState.stage_id === 'red_one_tap' && !window.discoBreakerState.finished"

jq -e -s 'length == 35 and all(.viewport.width == 390 and .viewport.height == 844)' "$inventory_file" >/dev/null
jq -e -s 'any(.[]; .action == "stage7-disabled-call") and any(.[]; .action == "stage7-skip-optional") and any(.[]; .action == "graduation-run-replay") and any(.[]; .action == "optional-skip-run-replay")' "$action_file" >/dev/null
montage_inputs=()
for index in "${!captures[@]}"; do
  printf -v label '%02d' "$((index + 1))"
  montage_inputs+=("(" "${captures[$index]}" -set label "$label" ")")
done
magick montage "${montage_inputs[@]}" -thumbnail 195x422 -tile 4x -geometry +8+24 -background '#120a24' -fill '#f7f1e3' -pointsize 14 artifacts/tutorial-audit-contact-sheet.png

chrome-devtools-axi console --type error >artifacts/browser-console.txt
printf 'PASS: browser audited 35 tutorial states and every connection box\n'
