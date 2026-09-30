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
async function captureState(name) {
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

async function cycleGrid3x3(stage) {
  const xs = [100, 195, 290];
  const ys = [214, 309, 404];
  for (let row = 0; row < 3; row += 1) {
    for (let column = 0; column < 3; column += 1) {
      if (stage !== "stage4" && stage !== "stage7" && row === 1 && column === 1) continue;
      await clickCanvas(xs[column], ys[row], 4);
    }
  }
}

try {
  await page.goto(baseUrl);
  await page.waitForTimeout(4000);

  await assertState("state.stage_id === 'red_one_tap'", "tutorial opens on stage 1");
  await captureState("stage1-intro-dialogue");
  await clickCanvas(195, 793);
  await captureState("stage1-pre-action");
  await cycleGrid3x3("stage1");
  await assertState("state.corrections.every((value) => value === 0)", "stage1 grid returns to neutral after cycling");
  await clickCanvas(195, 309);
  await assertState("state.result_visible && state.inspection.safe", "stage1 solve is logically safe");
  if ((await page.evaluate(() => window.discoBreakerFeedback)).success_count !== 1) throw new Error("stage1 reward must fire once");
  await captureState("stage1-success");
  await clickCanvas(195, 793);

  await captureState("stage2-intro-dialogue");
  await clickCanvas(195, 793);
  await cycleGrid3x3("stage2");
  await clickCanvas(195, 309);
  await clickCanvas(195, 309);
  await assertState("state.floor_dark", "stage2 solve darkens the floor");
  await captureState("stage2-success-blue");
  await clickCanvas(195, 793);

  await captureState("stage3-intro-dialogue");
  await clickCanvas(195, 793);
  await cycleGrid3x3("stage3");
  await clickCanvas(195, 309);
  await clickCanvas(195, 309);
  await clickCanvas(195, 309);
  await captureState("stage3-success-both");
  await clickCanvas(195, 793);

  await captureState("stage4-intro-dialogue");
  await clickCanvas(195, 793);
  await assertState("state.can_call_foreman", "stage4 allows calling the foreman before touching the grid");
  await cycleGrid3x3("stage4");
  await clickCanvas(195, 793);
  await assertState("state.inspection.safe", "stage4 inspection passes");
  await captureState("stage4-inspection-passed");
  await clickCanvas(195, 793);

  await captureState("stage5-intro-dialogue");
  await clickCanvas(195, 793);
  await assertState(
    "state.inspection.red_crossing && !state.inspection.blue_crossing",
    "stage5 crossing trap fails on the red family only",
  );
  await captureState("stage5-failure-witness");
  await clickCanvas(195, 793);

  await assertState("state.stage === 6 && state.stage_count === 7 && state.stage_id === 'boundary_single' && state.lit_red.length === 1 && state.lit_blue.length === 0", "single red boundary lesson");
  await captureState("stage6-red-intro");
  await clickCanvas(195,793);
  await captureState("stage6-red-ready");
  await clickCanvas(100,214);
  await assertState("state.floor_dark && state.inspection.safe && state.result_visible", "one tap safely clears red edge");
  await captureState("stage6-red-cleared");
  await clickCanvas(195,793);
  await assertState("state.stage === 6 && state.boundary_phase === 1 && state.lit_blue.length === 1 && state.lit_red.length === 0", "single blue boundary follows red");
  await captureState("stage6-blue-intro");
  await clickCanvas(195,793);
  await captureState("stage6-blue-ready");
  await clickCanvas(290,214);
  await assertState("!state.floor_dark && !state.result_visible", "red intermediate does not clear blue");
  await captureState("stage6-blue-intermediate-red");
  await clickCanvas(290,214);
  await assertState("state.floor_dark && state.inspection.safe && state.result_visible", "two taps safely clear blue edge");
  await captureState("stage6-blue-cleared");
  await clickCanvas(195,793);
  await captureState("stage7-intro-dialogue");
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await assertState(
    "!state.can_call_foreman && state.last_action.action === 'confirm_dialogue'",
    "stage7 foreman call stays disabled before the grid is wired",
  );
  await cycleGrid3x3("stage7");
  await assertState("state.grid_size === 3 && state.corrections.every(value => value === 0)", "final practice is a neutral 3x3 floor");
  await captureState("two-red-flickers-before");
  await clickCanvas(195,309);
  await assertState("state.lit_red.length === 0 && state.lit_blue.length > 0", "red immediately clears both adjacent red flickers");
  await captureState("two-red-flickers-after");
  await clickCanvas(195,309,3);
  await clickCanvas(195,309);
  await clickCanvas(290,214,2);
  await assertState("state.can_call_foreman", "stage7 wiring enables calling the foreman");
  await captureState("stage7-inspection-ready");
  await clickCanvas(195, 793);
  await assertState("state.inspection.safe", "stage7 graduation inspection passes");
  await captureState("stage7-graduation-passed");
  await clickCanvas(195, 793);
  await assertState("state.finished", "tutorial reports finished");
  const rewards = await page.evaluate(() => window.discoBreakerFeedback);
  if (rewards.success_count !== 7 || rewards.sound_starts !== 7) throw new Error(`unexpected tutorial rewards: ${JSON.stringify(rewards)}`);
  await captureState("tutorial-complete");
  await clickCanvas(195, 793);
  await assertState("state.stage_id === 'red_one_tap' && !state.finished", "replay resets to stage 1");

  await page.goto(baseUrl);
  await page.waitForTimeout(4000);
  await assertState("state.stage_id === 'red_one_tap'", "optional skip run opens on stage 1");
  await clickCanvas(195, 793);
  await clickCanvas(195, 309);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 309);
  await clickCanvas(195, 309);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 309);
  await clickCanvas(195, 309);
  await clickCanvas(195, 309);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await assertState("state.stage_id === 'boundary_single'", "skip run reaches boundary lesson");
  await clickCanvas(100,214);
  await clickCanvas(195,793);
  await clickCanvas(195,793);
  await clickCanvas(290,214,2);
  await clickCanvas(195,793);
  await clickCanvas(195,793);
  await assertState("state.stage_id === 'graduation_3x3' && !state.finished", "optional skip run reaches graduation");
  await clickCanvas(195, 735);
  await assertState("state.finished && state.last_action.action === 'skip_graduation'", "optional graduation skip finishes tutorial");
  await captureState("optional-graduation-skipped");
  await clickCanvas(195, 793);
  await assertState("state.stage_id === 'red_one_tap' && !state.finished", "optional skip replay resets to stage 1");

  // Native mobile touches must not also cycle a wire through emulated mouse input.
  const touchPage = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, deviceScaleFactor: 2 });
  touchPage.on("pageerror", (error) => consoleErrors.push(String(error)));
  touchPage.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
  await touchPage.goto(baseUrl);
  await touchPage.waitForFunction(() => window.discoBreakerState);
  const touch = async (x, y) => { await touchPage.touchscreen.tap(x, y); await touchPage.waitForTimeout(100); };
  await touch(195, 793);
  const initialCount = await touchPage.evaluate(() => window.discoBreakerState.action_count);
  for (let value = 1; value <= 4; value += 1) {
    await touch(100, 214);
    const state = await touchPage.evaluate(() => window.discoBreakerState);
    if (state.corrections[0] !== value % 4 || state.action_count !== initialCount + value) {
      throw new Error(`one touch must produce one wire change: ${JSON.stringify(state)}`);
    }
  }
  await touch(195, 309);
  const touched = await touchPage.evaluate(() => window.discoBreakerState);
  if (!touched.result_visible || !touched.floor_dark || touched.corrections[4] !== 1) throw new Error("native mobile touch failed to solve red lesson");
  await touchPage.screenshot({ path: `${artifactsDir}/mobile-touch-success.png` });
  await touchPage.close();

  if (consoleErrors.length > 0) {
    throw new Error(`console errors detected:\n${consoleErrors.join("\n")}`);
  }

  console.log(`PASS: browser audited ${captureIndex} tutorial states, every connection box, optional skip, and native mobile touch`);
} finally {
  await browser.close();
}
