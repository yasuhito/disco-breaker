// CI browser E2E check for the DISCO BREAKER tutorial Web export.
// Mirrors scripts/browser_e2e.sh (which uses the local-only chrome-devtools-axi
// tool) using Playwright, which is available on GitHub Actions runners.
// Drives every tutorial control through the same canvas input-injection
// surface, correlates window.discoBreakerState after each action, rejects
// console errors, and saves representative screenshots as a CI artifact.
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";

const baseUrl = process.env.DISCO_BREAKER_E2E_URL ?? "http://127.0.0.1:8877/index.html";
const artifactsDir = process.env.DISCO_BREAKER_E2E_ARTIFACTS ?? "artifacts/ci-e2e";

await mkdir(artifactsDir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

const consoleErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") {
    consoleErrors.push(message.text());
  }
});
page.on("pageerror", (error) => {
  consoleErrors.push(String(error));
});

let captureIndex = 0;
async function captureState(name, settle = 900) {
  // Let the foreman finish speaking and an inspection presentation settle (~2 s).
  await page.waitForTimeout(settle);
  captureIndex += 1;
  const sequence = String(captureIndex).padStart(2, "0");
  await page.screenshot({ path: `${artifactsDir}/ci-audit-${sequence}-${name}.png` });
}

async function clickCanvas(x, y, count = 1) {
  await page.evaluate(
    async ({ x, y, count }) => {
      const canvas = document.querySelector("canvas");
      const rect = canvas.getBoundingClientRect();
      for (let index = 0; index < count; index += 1) {
        const eventInit = { bubbles: true, clientX: rect.left + x, clientY: rect.top + y, button: 0 };
        canvas.dispatchEvent(new MouseEvent("mousedown", eventInit));
        canvas.dispatchEvent(new MouseEvent("mouseup", eventInit));
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    },
    { x, y, count },
  );
  await page.waitForTimeout(150);
}

// The title press dips for 0.15 s before the lesson opens, and the lesson's
// 280 ms input guard counts from that entry: wait for both before acting.
async function waitForLessonEntry(target) {
  await target.waitForFunction(() => window.discoBreakerState?.screen === "tutorial");
  await target.waitForTimeout(350);
}

async function assertState(predicate, description) {
  const holds = await page.evaluate((predicateSource) => {
    // eslint-disable-next-line no-new-func
    const fn = new Function("state", `return (${predicateSource});`);
    return Boolean(fn(window.discoBreakerState));
  }, predicate);
  if (!holds) {
    const state = await page.evaluate(() => window.discoBreakerState);
    throw new Error(`state assertion failed: ${description}\npredicate: ${predicate}\nstate: ${JSON.stringify(state)}`);
  }
}

// Lesson layout (390 x 844): connection boxes at x 102/194/286, y 304/396/488;
// the bottom button (Continue / call the foreman / Replay) at 194,760; the
// optional skip (and Back to title) at 194,668; home at 34,34.
const BOX_X = [102, 194, 286];
const BOX_Y = [304, 396, 488];
const box = (node, count = 1) => clickCanvas(BOX_X[node % 3], BOX_Y[Math.floor(node / 3)], count);
const bottom = () => clickCanvas(194, 760);

async function cycleGrid3x3(stage) {
  for (let node = 0; node < 9; node += 1) {
    if (stage !== "stage4" && stage !== "stage7" && node === 4) continue;
    await box(node, 4);
  }
}

try {
  await page.goto(baseUrl);
  await page.waitForTimeout(4000);

  await assertState("state.screen === 'title' && !state.campaign_available", "title opens with unavailable campaign");
  await captureState("title");
  const titleFeedback = await page.evaluate(() => window.discoBreakerFeedback);
  if (titleFeedback.title_presses !== 0 || titleFeedback.title_press_sound_starts !== 0) throw new Error(`no title audio before a press: ${JSON.stringify(titleFeedback)}`);
  // Three rapid clicks on the tutorial plate: one press, one press sound,
  // and nothing reaches the first lesson.
  await clickCanvas(195, 775, 3);
  await waitForLessonEntry(page);
  await assertState("state.screen === 'tutorial' && state.stage_id === 'red_one_tap' && state.schema === 'disco-breaker-tutorial-state.v2'", "tutorial opens on stage 1");
  await assertState("state.last_action.action === 'launch' && state.action_count === 1", "rapid title clicks never act on the first lesson");
  const pressFeedback = await page.evaluate(() => window.discoBreakerFeedback);
  if (pressFeedback.title_presses !== 1 || pressFeedback.title_press_sound_starts !== 1 || pressFeedback.title_pressing || pressFeedback.sound_starts !== 0) throw new Error(`one accepted title press plays its sound once: ${JSON.stringify(pressFeedback)}`);
  await assertState("!('dialogue_visible' in state) && state.utterance.kind === 'start' && !state.can_continue", "the board is editable at once with Continue disabled");
  await captureState("stage1-start");
  await bottom();
  await assertState("state.stage === 1 && state.last_action.action === 'launch'", "disabled Continue is inert");
  await cycleGrid3x3("stage1");
  await assertState("state.corrections.every((value) => value === 0)", "stage1 grid returns to neutral after cycling");
  await box(1);
  await box(7);
  await assertState("state.floor_dark && state.inspected && state.inspection.red_crossing && !state.can_continue && state.utterance.kind === 'unsafe'", "a dark but leaking board does not pass");
  await captureState("stage1-dark-leak", 2300);
  await box(1, 3);
  await box(7, 3);
  await box(4);
  await assertState("state.passed && state.can_continue && state.inspection.safe", "stage1 solve is logically safe");
  const firstReward = await page.evaluate(() => window.discoBreakerFeedback);
  if (firstReward.success_count !== 1 || firstReward.sound_starts !== 1 || firstReward.last_reward_sound !== "lesson1_bell") throw new Error(`stage1 must ring its bell once: ${JSON.stringify(firstReward)}`);
  await assertState("state.utterance.text === 'いいぞ！\\n赤い床のちらつきが\\n直ったね！'", "stage1 praise is the approved line");
  await captureState("stage1-pass");
  await bottom();

  await captureState("stage2-start");
  await cycleGrid3x3("stage2");
  await box(4, 2);
  await assertState("state.floor_dark && state.passed", "stage2 solve darkens the floor");
  if ((await page.evaluate(() => window.discoBreakerFeedback)).last_reward_sound !== "sting") throw new Error("stage2 keeps the default sting");
  await captureState("stage2-pass");
  await bottom();

  await captureState("stage3-start");
  await cycleGrid3x3("stage3");
  await box(4, 3);
  await assertState("state.passed", "stage3 solve passes");
  await captureState("stage3-pass");
  await bottom();

  await captureState("stage4-start");
  await assertState("state.can_call_foreman && state.inspection_mode === 'call'", "stage4 allows calling the foreman before touching the grid");
  await cycleGrid3x3("stage4");
  await box(1);
  await box(4, 3);
  await box(7);
  await bottom();
  await assertState("state.floor_dark && !state.inspection.safe && !state.can_continue && state.counting", "dark floor may fail inspection; the foreman counts first");
  await captureState("stage4-failed-inspection", 4000);
  await box(1, 3);
  await assertState("!state.inspected && state.stage === 4", "an edit clears the verdict and keeps the floor editable");
  await box(4);
  await box(7, 3);
  // Call the foreman, then tap Continue while he counts, in one browser step:
  // Continue must be inert until the count ends.
  const raced = await page.evaluate(async () => {
    const canvas = document.querySelector("canvas");
    const rect = canvas.getBoundingClientRect();
    const tap = async () => {
      const init = { bubbles: true, clientX: rect.left + 194, clientY: rect.top + 760, button: 0 };
      canvas.dispatchEvent(new MouseEvent("mousedown", init));
      canvas.dispatchEvent(new MouseEvent("mouseup", init));
      await new Promise((resolve) => setTimeout(resolve, 200));
    };
    await tap();
    const called = { ...window.discoBreakerState };
    await tap();
    return { called, stage: window.discoBreakerState.stage };
  });
  const called = raced.called;
  if (!(called.inspection.safe && called.passed && called.counting && !called.continue_enabled) || raced.stage !== 4) throw new Error(`stage4 must count before its verdict and Continue must not race it: ${JSON.stringify(raced)}`);
  await page.screenshot({ path: `${artifactsDir}/stage4-counting.png` });
  await page.waitForFunction(() => !window.discoBreakerState.counting, null, { timeout: 5000 });
  await assertState("state.continue_enabled && state.utterance.kind === 'safe'", "the verdict follows the count");
  await captureState("stage4-inspection-passed");
  await bottom();

  await captureState("stage5-start");
  await assertState("state.floor_dark && state.can_call_foreman && !state.fault_revealed", "stage5 trap looks cleared and hides its fault");
  await bottom();
  await assertState(
    "state.inspection.red_crossing && !state.inspection.blue_crossing && !state.passed && !state.can_continue && state.fault_revealed",
    "stage5 crossing trap fails on the red family only and does not pass",
  );
  const leak = await page.evaluate(() => window.discoBreakerFeedback);
  if (!leak.leak_active || leak.leak_events !== 3 || leak.leak_sound_starts !== 3 || JSON.stringify(leak.leak_routes[0].qubits) !== '[1,4,7]' || leak.revealed_hidden['4'] !== 1) throw new Error(`trap must reveal the original center X and its real residual route once: ${JSON.stringify(leak)}`);
  const live = await page.evaluate(() => document.getElementById("disco-breaker-live")?.textContent ?? "");
  if (!live.includes("漏電あり！床は2本で暗い。") || !live.includes("つづける はまだ押せない")) throw new Error(`the live region must announce the latest line and the button: ${live}`);
  await captureState("stage5-leak-explained", 2300);
  await bottom();
  await assertState("state.stage === 5 && state.last_action.action === 'inspect'", "Continue stays disabled after the leak");
  await box(1, 3);
  await assertState("!state.floor_dark && state.fault_revealed && state.utterance.text.includes('破線')", "the repair keeps the dashed fault");
  await box(7, 3);
  await box(4);
  await assertState("state.floor_dark && state.can_call_foreman && state.utterance.kind === 'ready'", "repaired trap asks for another inspection");
  await bottom();
  await assertState("state.passed && state.can_continue", "the repaired trap passes its inspection");
  await captureState("stage5-pass");
  await bottom();

  await assertState("state.stage === 6 && state.stage_count === 7 && state.stage_id === 'boundary_single' && state.lit_red.length === 1 && state.lit_blue.length === 0", "single red boundary lesson");
  const afterLeak = await page.evaluate(() => window.discoBreakerFeedback);
  if (afterLeak.leak_active || afterLeak.leak_routes.length || Object.keys(afterLeak.revealed_hidden).length) throw new Error('next lesson must remove cracks and answer reveal');
  await captureState("stage6-red-start");
  await box(0);
  await assertState("state.floor_dark && state.inspection.safe && state.passed && state.boundary_phase === 0", "one tap safely clears red edge; blue waits for Continue");
  await captureState("stage6-red-pass");
  await bottom();
  await assertState("state.stage === 6 && state.boundary_phase === 1 && state.lit_blue.length === 1 && state.lit_red.length === 0", "single blue boundary follows red");
  await captureState("stage6-blue-start");
  await box(2);
  await assertState("!state.floor_dark && !state.can_continue", "red intermediate does not clear blue");
  await captureState("stage6-blue-intermediate-red");
  await box(2);
  await assertState("state.floor_dark && state.inspection.safe && state.passed", "two taps safely clear blue edge");
  await captureState("stage6-blue-pass");
  await bottom();
  await captureState("stage7-start");
  await bottom();
  await assertState("!state.can_call_foreman && state.last_action.action === 'next_stage'", "stage7 foreman call stays disabled before the grid is wired");
  await cycleGrid3x3("stage7");
  await assertState("state.grid_size === 3 && state.corrections.every(value => value === 0)", "final practice is a neutral 3x3 floor");
  await captureState("two-red-flickers-before");
  await box(4);
  await assertState("state.lit_red.length === 0 && state.lit_blue.length > 0", "red immediately clears both adjacent red flickers");
  await captureState("two-red-flickers-after");
  await box(0, 2);
  await box(1, 2);
  await bottom();
  await assertState("state.inspection.blue_crossing && !state.inspection.red_crossing && state.utterance.text === '漏電あり！\\n青い線が左から右へ。'", "a blue leak is named blue");
  await captureState("stage7-blue-leak", 2300);
  await box(1);
  await box(7);
  await box(4, 3);
  await bottom();
  await assertState("state.inspection.blue_crossing && state.inspection.red_crossing && state.utterance.text === '漏電あり！\\n赤も青も抜けている。'", "a leak in both colours names both");
  const both = await page.evaluate(() => window.discoBreakerFeedback);
  if (both.leak_routes.length !== 2) throw new Error(`both colours need their own route: ${JSON.stringify(both)}`);
  await captureState("stage7-both-leak", 2300);
  await box(0, 2);
  await box(1);
  await box(7, 3);
  await box(4);
  await box(2, 2);
  await assertState("state.can_call_foreman", "stage7 wiring enables calling the foreman");
  await captureState("stage7-inspection-ready");
  await bottom();
  await assertState("state.inspection.safe && state.passed", "stage7 graduation inspection passes");
  await captureState("stage7-graduation-passed");
  await bottom();
  await assertState("state.finished && !state.skipped", "tutorial reports finished");
  const rewards = await page.evaluate(() => window.discoBreakerFeedback);
  if (rewards.success_count !== 8 || rewards.sound_starts !== 8) throw new Error(`unexpected tutorial rewards: ${JSON.stringify(rewards)}`);
  await captureState("tutorial-complete");
  await bottom();
  await assertState("state.stage_id === 'red_one_tap' && !state.finished", "replay resets to stage 1");

  await page.goto(baseUrl);
  await page.waitForTimeout(4000);
  await clickCanvas(195, 775);
  await waitForLessonEntry(page);
  await assertState("state.stage_id === 'red_one_tap'", "optional skip run opens on stage 1");
  await box(4);
  await bottom();
  await box(4, 2);
  await bottom();
  await box(4, 3);
  await bottom();
  await bottom();
  await page.waitForTimeout(1800); // the foreman counts
  await bottom();
  await bottom();
  await box(1, 3);
  await box(7, 3);
  await box(4);
  await bottom();
  await bottom();
  await assertState("state.stage_id === 'boundary_single'", "skip run reaches boundary lesson");
  await box(0);
  await bottom();
  await box(2, 2);
  await bottom();
  await assertState("state.stage_id === 'graduation_3x3' && !state.finished", "optional skip run reaches graduation");
  await clickCanvas(194, 668);
  await assertState("state.finished && state.skipped && !state.passed && state.last_action.action === 'skip_graduation'", "optional graduation skip finishes tutorial without a pass");
  await captureState("optional-graduation-skipped");
  await bottom();
  await assertState("state.stage_id === 'red_one_tap' && !state.finished", "optional skip replay resets to stage 1");

  // Native mobile touches must not also cycle a wire through emulated mouse input.
  const touchPage = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, deviceScaleFactor: 2 });
  touchPage.on("pageerror", (error) => consoleErrors.push(String(error)));
  touchPage.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
  await touchPage.goto(baseUrl);
  await touchPage.waitForFunction(() => window.discoBreakerState);
  const touch = async (x, y) => { await touchPage.touchscreen.tap(x, y); await touchPage.waitForTimeout(100); };
  await touchPage.touchscreen.tap(195, 775);
  await touch(195, 775);
  await waitForLessonEntry(touchPage);
  const touchPress = await touchPage.evaluate(() => ({ state: window.discoBreakerState, feedback: window.discoBreakerFeedback }));
  if (touchPress.state.screen !== "tutorial" || touchPress.state.action_count !== 1 || touchPress.feedback.title_presses !== 1 || touchPress.feedback.title_press_sound_starts !== 1) throw new Error(`a rapid double touch is one title press: ${JSON.stringify(touchPress)}`);
  const initialCount = await touchPage.evaluate(() => window.discoBreakerState.action_count);
  for (let value = 1; value <= 4; value += 1) {
    await touch(102, 304);
    const state = await touchPage.evaluate(() => window.discoBreakerState);
    if (state.corrections[0] !== value % 4 || state.action_count !== initialCount + value) {
      throw new Error(`one touch must produce one wire change: ${JSON.stringify(state)}`);
    }
  }
  await touch(194, 396);
  const touched = await touchPage.evaluate(() => window.discoBreakerState);
  if (!touched.passed || !touched.floor_dark || touched.corrections[4] !== 1) throw new Error("native mobile touch failed to solve red lesson");
  await touchPage.screenshot({ path: `${artifactsDir}/mobile-touch-success.png` });
  await touchPage.close();

  if (consoleErrors.length > 0) {
    throw new Error(`console errors detected:\n${consoleErrors.join("\n")}`);
  }

  await import("./title_e2e.mjs");
  console.log(`PASS: browser audited ${captureIndex} tutorial states, every connection box, optional skip, and native mobile touch`);
} finally {
  await browser.close();
}
