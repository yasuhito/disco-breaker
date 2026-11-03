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
  # Let the foreman finish speaking and an inspection presentation settle (~2 s).
  sleep "${3:-0.9}"
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

# The title press dips for 0.15 s before the lesson opens, and the lesson's
# 280 ms input guard counts from that entry: wait (in the page, at most 3 s)
# for both before acting.
wait_for_lesson_entry() {
  chrome-devtools-axi eval "async () => { const until = performance.now() + 3000; while (window.discoBreakerState?.screen !== 'tutorial') { if (performance.now() > until) throw new Error('lesson did not open'); await new Promise(resolve => setTimeout(resolve, 20)); } await new Promise(resolve => setTimeout(resolve, 350)); return true; }" >/dev/null
}

# Lessons 4 and 5 check for 1.0 s before the verdict is presented; wait (in
# the page, at most 3 s) for the check to end before relying on it.
wait_for_check_end() {
  chrome-devtools-axi eval "async () => { const until = performance.now() + 3000; while (window.discoBreakerState.counting) { if (performance.now() > until) throw new Error('the check did not end'); await new Promise(resolve => setTimeout(resolve, 20)); } return true; }" >/dev/null
}

assert_state() {
  local expression="$1"
  chrome-devtools-axi eval "() => { if (!(${expression})) throw new Error('state assertion failed'); return JSON.stringify(window.discoBreakerState); }" >/dev/null
}

cycle_grid_3x3() {
  local stage="$1"
  local xs=(102 194 286)
  local ys=(304 396 488)
  for row in 0 1 2; do
    for column in 0 1 2; do
      if [[ "$stage" != "stage4" && "$stage" != "stage7" && "$row" == "1" && "$column" == "1" ]]; then
        continue
      fi
      click_canvas "${xs[$column]}" "${ys[$row]}" "${stage}-cycle-box-${row}-${column}" 4
    done
  done
}

# Lesson layout (390 x 844): connection boxes at x 102/194/286, y 304/396/488;
# the bottom button (Continue / call the foreman / Replay) at 194,760; the
# optional skip (and Back to title) at 194,668; home at 34,34.
S="window.discoBreakerState"
F="window.discoBreakerFeedback"
assert_state "${S}.screen === 'title' && !${S}.campaign_available"
assert_state "${F}.title_presses === 0 && ${F}.title_press_sound_starts === 0"
# Three rapid clicks on the tutorial plate: one press, one press sound, and
# nothing reaches the first lesson.
click_canvas 195 775 title-enter-tutorial 3
wait_for_lesson_entry
assert_state "${S}.screen === 'tutorial' && ${S}.stage_id === 'red_one_tap' && ${S}.schema === 'disco-breaker-tutorial-state.v2'"
assert_state "${S}.last_action.action === 'launch' && ${S}.action_count === 1"
assert_state "${F}.title_presses === 1 && ${F}.title_press_sound_starts === 1 && !${F}.title_pressing && ${F}.sound_starts === 0"
assert_state "!('dialogue_visible' in ${S}) && ${S}.utterance.kind === 'start' && !${S}.can_continue"
capture_state 01 stage1-start
chrome-devtools-axi screenshot artifacts/tutorial-stage-1.png >/dev/null
click_canvas 194 760 stage1-disabled-continue
assert_state "${S}.stage === 1 && ${S}.last_action.action === 'launch'"
cycle_grid_3x3 stage1
assert_state "${S}.corrections.every(value => value === 0) && ${S}.utterance.kind === 'mistake'"
capture_state 02 stage1-mistake
click_canvas 194 304 stage1-leak-top
click_canvas 194 488 stage1-leak-bottom
assert_state "${S}.floor_dark && ${S}.inspected && ${S}.inspection.red_crossing && !${S}.can_continue && ${S}.utterance.kind === 'unsafe'"
capture_state 03 stage1-dark-leak 2.3
click_canvas 194 760 stage1-leak-continue-disabled
assert_state "${S}.stage === 1 && ${S}.last_action.action === 'inspect'"
click_canvas 194 304 stage1-undo-top 3
click_canvas 194 488 stage1-undo-bottom 3
click_canvas 194 396 stage1-target-red
assert_state "${S}.passed && ${S}.can_continue && ${S}.inspection.safe && ${S}.last_action.payload.auto"
capture_state 04 stage1-pass
click_canvas 194 760 stage1-continue

assert_state "${S}.stage_id === 'blue_two_taps' && ${S}.utterance.kind === 'start'"
capture_state 05 stage2-start
cycle_grid_3x3 stage2
assert_state "${S}.corrections.every(value => value === 0)"
click_canvas 194 396 stage2-cycle-red
# The red tap marks the two red floors it lit; the blue tap the four it darkened.
assert_state "${F}.wiring.darkened.length === 0 && ${F}.wiring.lit.map(f => f.component + ':' + f.check).join() === '1:0,1:1' && ${F}.wiring.wires.map(w => w.component + ':' + w.present).join() === '1:true'"
assert_state "!${S}.floor_dark && ${S}.utterance.text === '赤い配線になったね。\\nもう1回タップして、\\n青い配線に変えよう！'"
capture_state 06 stage2-intermediate-red
click_canvas 194 396 stage2-cycle-blue
assert_state "${S}.floor_dark && ${S}.passed"
assert_state "${F}.wiring.lit.length === 0 && ${F}.wiring.darkened.map(f => f.component + ':' + f.check).join() === '1:0,1:1,2:0,2:1' && ${F}.wiring.wires.map(w => w.component + ':' + w.present).join() === '1:false,2:true' && ${F}.wiring.node === 4"
capture_state 07 stage2-pass
click_canvas 194 760 stage2-continue

capture_state 08 stage3-start
assert_state "${S}.stage_id === 'combined_three_taps' && ${S}.title === '両方のちらつきを直そう' && ${S}.utterance.text === '赤も青もちらついてるね。\\n真ん中を3回タップして、\\n両方の配線で直そう！'"
chrome-devtools-axi screenshot artifacts/tutorial-dialogue-wrap.png >/dev/null
cycle_grid_3x3 stage3
assert_state "${S}.corrections.every(value => value === 0)"
click_canvas 194 396 stage3-cycle-red
capture_state 09 stage3-intermediate-red
click_canvas 194 396 stage3-cycle-blue
capture_state 10 stage3-intermediate-blue
click_canvas 194 396 stage3-cycle-both
assert_state "${S}.passed && ${S}.utterance.text === 'いいぞ！\\n赤と青のちらつきが\\nどちらも直ったね！'"
capture_state 11 stage3-pass
click_canvas 194 760 stage3-continue

assert_state "${S}.stage_id === 'foreman_inspection' && ${S}.inspection_mode === 'call' && ${S}.can_call_foreman"
assert_state "${S}.title === 'でも、安全かな？' && ${S}.utterance.text === 'ちらつきは全部消えたね。\\nでも、電気がもれてるかも。\\n安全かどうかチェックしよう！' && document.getElementById('disco-breaker-live').textContent.endsWith('チェックして！ を押せる')"
capture_state 12 stage4-start
cycle_grid_3x3 stage4
assert_state "${S}.can_call_foreman"
click_canvas 194 304 stage4-leak-top-red
assert_state "!${S}.can_call_foreman && document.getElementById('disco-breaker-live').textContent.endsWith('チェックして！ はまだ押せない')"
click_canvas 194 396 stage4-leak-center-blue 3
click_canvas 194 488 stage4-leak-bottom-red
# The check lasts 1.0 s; assert it in the same browser step as the call, as
# separate commands can take longer than that on a loaded host.
chrome-devtools-axi eval "async () => { const c=document.querySelector('canvas'); const r=c.getBoundingClientRect(); const e={bubbles:true,clientX:r.left+194,clientY:r.top+760,button:0}; c.dispatchEvent(new MouseEvent('mousedown',e)); c.dispatchEvent(new MouseEvent('mouseup',e)); await new Promise(resolve => setTimeout(resolve,200)); const s=window.discoBreakerState; if (!(s.floor_dark && !s.inspection.safe && !s.can_continue && !s.can_call_foreman && s.counting && document.getElementById('disco-breaker-live').textContent.endsWith('チェックして！ はまだ押せない'))) throw new Error('the foreman must count before his unsafe verdict'); return true; }" >/dev/null
record_action stage4-call-unsafe
capture_state 13 stage4-failed-inspection 4.0
click_canvas 194 304 stage4-undo-top 3
assert_state "${S}.stage === 4 && !${S}.inspected"
click_canvas 194 396 stage4-undo-center
click_canvas 194 488 stage4-undo-bottom 3
# Call the foreman, then tap Continue while he counts, in one browser step:
# Continue must be inert until the count ends.
chrome-devtools-axi eval "async () => { const c=document.querySelector('canvas'); const r=c.getBoundingClientRect(); const tap = async () => { const e={bubbles:true,clientX:r.left+194,clientY:r.top+760,button:0}; c.dispatchEvent(new MouseEvent('mousedown',e)); c.dispatchEvent(new MouseEvent('mouseup',e)); await new Promise(resolve => setTimeout(resolve,200)); }; await tap(); const s=window.discoBreakerState; if (!(s.inspection.safe && s.passed && s.counting && !s.continue_enabled)) throw new Error('the foreman must count first'); await tap(); if (window.discoBreakerState.stage !== 4) throw new Error('Continue raced the count'); return true; }" >/dev/null
record_action stage4-call-foreman
record_action stage4-continue-during-count
sleep 1.6
assert_state "!${S}.counting && ${S}.continue_enabled && ${S}.utterance.kind === 'safe' && ${S}.utterance.text === 'よし、電気はもれてないね。\\nこれで安心！'"
capture_state 14 stage4-inspection-passed
chrome-devtools-axi screenshot artifacts/tutorial-inspection-dialogue.png >/dev/null
click_canvas 194 760 stage4-continue

assert_state "${S}.stage_id === 'crossing_trap' && ${S}.floor_dark && ${S}.can_call_foreman && !${S}.fault_revealed"
capture_state 15 stage5-start
click_canvas 194 760 stage5-call-trap
assert_state "${S}.inspection.red_crossing && !${S}.inspection.blue_crossing && !${S}.passed && !${S}.can_continue && ${S}.fault_revealed"
# Lesson 5 checks for 1.0 s, then explains the leak step by step.
wait_for_check_end
assert_state "${S}.explain_step >= 0 && document.getElementById('disco-breaker-live').textContent.includes('電気がもれているよ！') && !document.getElementById('disco-breaker-live').textContent.includes('漏電')"
capture_state 16 stage5-leak-explained 2.3
chrome-devtools-axi screenshot artifacts/tutorial-crossing-trap.png >/dev/null
click_canvas 194 760 stage5-no-continue-after-leak
assert_state "${S}.stage === 5 && ${S}.last_action.action === 'inspect'"
click_canvas 194 304 stage5-repair-top 3
assert_state "!${S}.floor_dark && ${S}.fault_revealed && ${S}.explain_step === -1 && ${S}.utterance.text === '光る床がある。\\nまず全部暗くしよう。'"
capture_state 17 stage5-repair-lit
click_canvas 194 488 stage5-repair-bottom 3
click_canvas 194 396 stage5-repair-center
assert_state "${S}.floor_dark && ${S}.can_call_foreman && ${S}.utterance.kind === 'ready'"
capture_state 18 stage5-repair-dark
click_canvas 194 760 stage5-call-repaired
assert_state "${S}.passed && ${S}.can_continue"
wait_for_check_end
assert_state "${S}.continue_enabled && ${S}.utterance.text === 'よし、電気はもれてないね。\\n上の段の赤い印は0こ。\\nあまりなし。'"
capture_state 19 stage5-pass
click_canvas 194 760 stage5-continue

assert_state "${S}.stage === 6 && ${S}.stage_count === 7 && ${S}.lit_red.length === 1 && ${S}.lit_blue.length === 0 && !${S}.fault_revealed"
capture_state 20 stage6-red-start
click_canvas 102 304 stage6-red-edge
assert_state "${S}.floor_dark && ${S}.inspection.safe && ${S}.boundary_phase === 0 && ${S}.can_continue"
capture_state 21 stage6-red-pass
click_canvas 194 760 stage6-continue-blue
assert_state "${S}.stage === 6 && ${S}.boundary_phase === 1 && ${S}.lit_blue.length === 1 && ${S}.lit_red.length === 0"
capture_state 22 stage6-blue-start
click_canvas 286 304 stage6-blue-intermediate-red
assert_state "!${S}.floor_dark && !${S}.can_continue"
capture_state 23 stage6-blue-intermediate-red
click_canvas 286 304 stage6-blue-edge
assert_state "${S}.floor_dark && ${S}.inspection.safe && ${S}.passed"
capture_state 24 stage6-blue-pass
click_canvas 194 760 stage6-continue

capture_state 25 stage7-start
click_canvas 194 760 stage7-disabled-call
assert_state "!${S}.can_call_foreman && ${S}.last_action.action === 'next_stage' && document.getElementById('disco-breaker-live').textContent.endsWith('チェックして！ はまだ押せない')"
cycle_grid_3x3 stage7
assert_state "${S}.grid_size === 3 && ${S}.corrections.every(value => value === 0)"
capture_state 26 two-red-flickers-before
click_canvas 194 396 stage7-regression-center-red
assert_state "${S}.lit_red.length === 0 && ${S}.lit_blue.length > 0"
capture_state 27 two-red-flickers-after
click_canvas 102 304 stage7-blue-leak-corner 2
click_canvas 194 304 stage7-blue-leak-top 2
click_canvas 194 760 stage7-call-blue-leak
assert_state "${S}.inspection.blue_crossing && !${S}.inspection.red_crossing && ${S}.utterance.text === '電気がもれているよ！\n赤：上の段 0こ→あまり0こ\n青：左の列 1こ→あまり1こ'"
capture_state 28 stage7-blue-leak 2.3
click_canvas 194 304 stage7-both-leak-top 1
click_canvas 194 488 stage7-both-leak-bottom
click_canvas 194 396 stage7-both-leak-center 3
click_canvas 194 760 stage7-call-both-leak
assert_state "${S}.inspection.blue_crossing && ${S}.inspection.red_crossing && ${S}.utterance.text === '電気がもれているよ！\n赤：上の段 1こ→あまり1こ\n青：左の列 1こ→あまり1こ'"
capture_state 29 stage7-both-leak 2.3
click_canvas 102 304 stage7-undo-corner 2
click_canvas 194 304 stage7-undo-top
click_canvas 194 488 stage7-undo-bottom 3
click_canvas 194 396 stage7-place-center-red
capture_state 30 stage7-after-center-red
click_canvas 286 304 stage7-corner-cycle-red
capture_state 31 stage7-corner-intermediate-red
click_canvas 286 304 stage7-corner-cycle-blue
assert_state "${S}.can_call_foreman && ${S}.utterance.kind === 'ready'"
capture_state 32 stage7-inspection-ready
click_canvas 194 760 stage7-call-foreman
assert_state "${S}.inspection.safe && ${S}.passed"
capture_state 33 stage7-graduation-passed
chrome-devtools-axi screenshot artifacts/tutorial-graduation.png >/dev/null
click_canvas 194 760 stage7-complete
assert_state "${S}.finished && !${S}.skipped && ${S}.utterance.kind === 'done'"
capture_state 34 tutorial-complete
click_canvas 194 760 graduation-run-replay
assert_state "${S}.stage_id === 'red_one_tap' && !${S}.finished && ${S}.last_action.action === 'restart'"

# A second deterministic run exercises the optional skip button without
# replacing the full graduation path above.
run_name="optional-skip"
chrome-devtools-axi open http://127.0.0.1:8877/index.html >/dev/null
sleep 4
click_canvas 195 775 skip-run-title-enter
wait_for_lesson_entry
click_canvas 194 396 skip-run-stage1-solve
click_canvas 194 760 skip-run-stage1-continue
click_canvas 194 396 skip-run-stage2-solve 2
click_canvas 194 760 skip-run-stage2-continue
click_canvas 194 396 skip-run-stage3-solve 3
click_canvas 194 760 skip-run-stage3-continue
click_canvas 194 760 skip-run-stage4-call
sleep 1.8
click_canvas 194 760 skip-run-stage4-continue
click_canvas 194 760 skip-run-stage5-call
click_canvas 194 304 skip-run-stage5-repair-top 3
click_canvas 194 488 skip-run-stage5-repair-bottom 3
click_canvas 194 396 skip-run-stage5-repair-center
click_canvas 194 760 skip-run-stage5-call-again
wait_for_check_end
click_canvas 194 760 skip-run-stage5-continue
assert_state "${S}.stage_id === 'boundary_single'"
click_canvas 102 304 skip-run-stage6-red
click_canvas 194 760 skip-run-stage6-continue-blue
click_canvas 286 304 skip-run-stage6-blue 2
click_canvas 194 760 skip-run-stage6-continue
assert_state "${S}.stage_id === 'graduation_3x3' && !${S}.finished"
click_canvas 194 668 stage7-skip-optional
assert_state "${S}.finished && ${S}.skipped && !${S}.passed && ${S}.last_action.action === 'skip_graduation'"
capture_state 35 optional-graduation-skipped
click_canvas 194 760 optional-skip-run-replay
assert_state "${S}.stage_id === 'red_one_tap' && !${S}.finished"

jq -e -s 'length == 35 and all(.viewport.width == 390 and .viewport.height == 844)' "$inventory_file" >/dev/null
jq -e -s 'any(.[]; .action == "stage7-disabled-call") and any(.[]; .action == "stage7-skip-optional") and any(.[]; .action == "graduation-run-replay") and any(.[]; .action == "optional-skip-run-replay") and all(.[]; .state.dialogue_visible == null)' "$action_file" >/dev/null
montage_inputs=()
for index in "${!captures[@]}"; do
  printf -v label '%02d' "$((index + 1))"
  montage_inputs+=("(" "${captures[$index]}" -set label "$label" ")")
done
magick montage "${montage_inputs[@]}" -thumbnail 195x422 -tile 5x -geometry +8+24 -background '#120a24' -fill '#f7f1e3' -pointsize 14 artifacts/tutorial-audit-contact-sheet.png

chrome-devtools-axi console --type error >artifacts/browser-console.txt
printf 'PASS: browser audited 35 tutorial states and every connection box\n'
