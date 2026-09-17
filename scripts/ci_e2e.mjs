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
      if (stage !== "stage4" && row === 1 && column === 1) continue;
      await clickCanvas(xs[column], ys[row], 4);
    }
  }
}

async function cycleGrid5x5() {
  const xs = [60, 127, 195, 263, 330];
  const ys = [191, 258, 326, 394, 461];
  for (let row = 0; row < 5; row += 1) {
    for (let column = 0; column < 5; column += 1) {
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
  await assertState("state.result_visible", "stage1 solve reveals result");
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

  await captureState("stage6-intro-dialogue");
  await clickCanvas(195, 793);
  await clickCanvas(195, 793);
  await assertState(
    "!state.can_call_foreman && state.last_action.action === 'confirm_dialogue'",
    "stage6 foreman call stays disabled before the grid is wired",
  );
  await cycleGrid5x5();
  await assertState("state.corrections.every((value) => value === 0)", "stage6 5x5 grid returns to neutral after cycling");
  await clickCanvas(195, 326);
  await clickCanvas(263, 191);
  await clickCanvas(263, 191);
  await clickCanvas(127, 461);
  await assertState("state.can_call_foreman", "stage6 wiring enables calling the foreman");
  await captureState("stage6-inspection-ready");
  await clickCanvas(195, 793);
  await assertState("state.inspection.safe", "stage6 graduation inspection passes");
  await captureState("stage6-graduation-passed");
  await clickCanvas(195, 793);
  await assertState("state.finished", "tutorial reports finished");
  await captureState("tutorial-complete");
  await clickCanvas(195, 793);
  await assertState("state.stage_id === 'red_one_tap' && !state.finished", "replay resets to stage 1");

  if (consoleErrors.length > 0) {
    throw new Error(`console errors detected:\n${consoleErrors.join("\n")}`);
  }

  console.log(`PASS: browser audited ${captureIndex} tutorial states and every connection box`);
} finally {
  await browser.close();
}
