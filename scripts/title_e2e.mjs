// Title/navigation regression, also imported by ci_e2e.mjs.
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import assert from 'node:assert/strict';
const url = process.env.DISCO_BREAKER_E2E_URL ?? 'http://127.0.0.1:8877/index.html';
const out = process.env.DISCO_BREAKER_E2E_ARTIFACTS ?? 'artifacts/ci-e2e';
await mkdir(out, { recursive: true });
const browser = await chromium.launch();
const errors = [];
async function create(options = {}) {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, ...options });
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if(m.type() === 'error') errors.push(m.text()); });
  await page.goto(url);
  await page.waitForFunction(() => window.discoBreakerState?.screen === 'title');
  await page.waitForTimeout(300);
  return page;
}
async function tap(page, x, y, wait = 110) {
  const { width, height } = page.viewportSize();
  const scale = Math.min(width/390, height/844);
  await page.mouse.click((width-390*scale)/2+x*scale, (height-844*scale)/2+y*scale);
  await page.waitForTimeout(wait);
}
const state = p => p.evaluate(() => window.discoBreakerState);
const feedback = p => p.evaluate(() => window.discoBreakerFeedback);
let tutorialButton;
async function captureTitle(page, phase) {
  const before = await state(page);
  assert.equal(before.screen, 'title');
  assert.equal(before.campaign_available, false);
  await tap(page,195,675);
  assert.deepEqual(await state(page), before, `${phase}: Start remains disabled`);
  // Both patches are inside the flat cap, away from the centered label.
  // Only a trailing chevron would distinguish the right patch.
  assert.deepEqual(
    await page.screenshot({clip:{x:336,y:768,width:12,height:14}}),
    await page.screenshot({clip:{x:316,y:768,width:12,height:14}}),
    `${phase}: title tutorial has no trailing chevron`,
  );
  const button = await page.screenshot({clip:{x:24,y:744,width:342,height:62}});
  if (tutorialButton) assert.deepEqual(button, tutorialButton, `${phase}: tutorial label stays unchanged`);
  else tutorialButton = button;
  await page.screenshot({path:`${out}/title-${phase}-390x844.png`});
  await page.setViewportSize({width:1440,height:900});
  await page.waitForTimeout(110);
  await page.screenshot({path:`${out}/title-${phase}-1440x900.png`});
  await page.setViewportSize({width:390,height:844});
  await page.waitForTimeout(110);
}
async function captureAudioToggle(page, screen) {
  assert.equal((await feedback(page)).muted, false);
  for (const muted of [false, true]) {
    if (muted) await tap(page,325,36);
    assert.equal((await feedback(page)).muted, muted);
    for (const [width,height] of [[390,844],[1440,900]]) {
      await page.setViewportSize({width,height});
      await page.waitForTimeout(110);
      await page.screenshot({path:`${out}/${screen}-audio-${muted ? 'off' : 'on'}-${width}x${height}.png`});
    }
    await page.setViewportSize({width:390,height:844});
    await page.waitForTimeout(110);
  }
  await tap(page,325,36);
  assert.equal((await feedback(page)).muted, false);
}
try {
  const page = await create();
  const launch = await state(page);
  await captureTitle(page, 'initial');
  assert.equal(launch.campaign_available, false);
  await tap(page,195,675); // unavailable campaign
  await tap(page,195,500); // decorative floor
  assert.deepEqual(await state(page), launch);
  assert.equal((await feedback(page)).sound_starts, 0);
  assert.equal((await feedback(page)).lamp_sound_starts, 0);
  await page.screenshot({ path: `${out}/title-reflections-a.png` });
  // The turning mirror ball and the rays leaving its facets. (In the approved
  // layout no ray reaches the floor, whose lamps flicker on their own
  // schedule; tests/title_geometry.gd checks that deterministically.)
  const mirrorA = await page.screenshot({clip:{x:0,y:0,width:390,height:180}});
  await page.waitForTimeout(1700);
  await page.screenshot({ path: `${out}/title-reflections-b.png` });
  assert.notDeepEqual(await page.screenshot({clip:{x:0,y:0,width:390,height:180}}), mirrorA, 'mirror ball and rays move');
  assert.deepEqual(await state(page), launch, 'animation cannot change gameplay');
  // Entry and the lesson's bottom button overlap; a rapid second click cannot act.
  await tap(page,195,775,35);
  const entered = await state(page);
  await tap(page,195,760,35);
  assert.equal((await state(page)).action_count, entered.action_count);
  assert.equal((await state(page)).dialogue_visible, undefined, 'no dialogue gate');
  await page.waitForTimeout(300);
  await page.screenshot({path:`${out}/tutorial-start-390x844.png`});
  await tap(page,102,304);
  const playing = await state(page);
  await tap(page,38,36,350);
  const home = await state(page);
  assert.equal(home.screen,'title');
  assert.deepEqual(home.corrections, playing.corrections);
  await captureTitle(page, 'resume');
  const count = (await feedback(page)).lamp_sound_starts;
  await page.waitForTimeout(700);
  assert.equal((await feedback(page)).lamp_sound_starts,count,'no tutorial lamp sound on title');
  await tap(page,195,775,350);
  const resumed = await state(page);
  assert.deepEqual(resumed, playing, 'continue preserves entire semantic state');
  // Cancel the edge wire, solve, and resume an existing success without a second sting.
  for(let i=0;i<3;i++) await tap(page,102,304);
  await tap(page,194,396);
  const solved = await feedback(page);
  assert.equal(solved.success_count,1);
  await tap(page,38,36,350);
  await tap(page,195,775,350);
  assert.equal((await feedback(page)).sound_starts,solved.sound_starts);
  assert.equal((await state(page)).can_continue,true,'a resumed pass keeps Continue');
  await tap(page,194,760); // next
  await tap(page,194,396);
  await tap(page,194,396);
  await tap(page,194,760); // combined
  for(let i=0;i<3;i++) await tap(page,194,396);
  await tap(page,194,760); // inspection
  await tap(page,194,760,1800); // the foreman counts
  await tap(page,194,760);
  await tap(page,194,760); // trap
  assert.equal((await feedback(page)).leak_active,true);
  const leakCount=(await feedback(page)).leak_sound_starts;
  await tap(page,38,36,350);
  assert.equal((await feedback(page)).leak_active,false);
  assert.deepEqual((await feedback(page)).revealed_hidden,{});
  await tap(page,195,775,350);
  assert.equal((await feedback(page)).leak_active,true);
  assert.equal((await feedback(page)).leak_sound_starts,leakCount);
  for(let i=0;i<3;i++) await tap(page,194,304);
  for(let i=0;i<3;i++) await tap(page,194,488);
  await tap(page,194,396);
  await tap(page,194,760); // repaired trap
  await tap(page,194,760); // boundary
  await tap(page,102,304);
  await tap(page,194,760);
  await tap(page,286,304);
  await tap(page,286,304);
  await tap(page,194,760); // final
  await tap(page,194,668); // skip
  assert.equal((await state(page)).finished,true);
  assert.equal((await state(page)).skipped,true);
  await page.screenshot({path:`${out}/tutorial-skipped-390x844.png`});
  await tap(page,194,668,350); // explicit Back to title
  assert.equal((await state(page)).screen,'title');
  await captureTitle(page, 'completed');
  await page.screenshot({path:`${out}/title-after-completion.png`});
  await tap(page,195,775,350); // replay
  assert.equal((await state(page)).stage,1);
  assert.equal((await state(page)).last_action.action,'restart');
  assert.equal((await state(page)).utterance.kind,'start');
  assert.equal((await state(page)).finished,false);
  assert.equal((await feedback(page)).leak_active,false);
  // Shared mute across title, tutorial and a browser reload.
  await tap(page,38,36,350);
  await tap(page,325,36);
  assert.equal((await feedback(page)).muted,true);
  await tap(page,195,775,350);
  await tap(page,194,396);
  assert.equal((await feedback(page)).sound_starts,solved.sound_starts+6); // prior safe lessons only, muted replay adds zero
  await page.reload();
  await page.waitForFunction(()=>window.discoBreakerState?.screen==='title');
  assert.equal((await feedback(page)).muted,true);
  await page.close();
  // The actual rendered title remains identical over time in reduced motion.
  const quiet = await create({reducedMotion:'reduce'});
  const still = await quiet.screenshot({path:`${out}/title-reduced-motion.png`});
  await quiet.waitForTimeout(1100);
  assert.deepEqual(await quiet.screenshot(),still,'reduced-motion title is static');
  assert.equal((await feedback(quiet)).reduced_motion,true);
  assert.equal((await feedback(quiet)).lamp_sound_starts,0);
  await captureAudioToggle(quiet, 'title');
  await tap(quiet,195,775,350);
  await captureAudioToggle(quiet, 'tutorial');
  await tap(quiet,102,304);
  await quiet.waitForTimeout(700);
  assert.equal((await feedback(quiet)).lamp_sound_starts,0);
  // Reduced motion: a lesson, and a leak explanation, are drawn in their final static state.
  const lesson = await quiet.screenshot();
  await quiet.waitForTimeout(1100);
  assert.deepEqual(await quiet.screenshot(),lesson,'reduced-motion lesson is static');
  for(let i=0;i<3;i++) await tap(quiet,102,304);
  await tap(quiet,194,304);
  await tap(quiet,194,488);
  assert.equal((await state(quiet)).utterance.kind,'unsafe');
  const leakStill = await quiet.screenshot({path:`${out}/tutorial-reduced-motion-leak.png`});
  await quiet.waitForTimeout(1100);
  assert.deepEqual(await quiet.screenshot(),leakStill,'reduced-motion leak explanation is static and complete at once');
  await quiet.close();
  for(const [width,height] of [[320,568],[412,915],[844,390]]) {
    const mobile = await create({viewport:{width,height},reducedMotion:'reduce'});
    await mobile.screenshot({path:`${out}/title-${width}x${height}.png`});
    // The tutorial plate is its drawn bounds (28,752 332x60), lip included.
    await tap(mobile,195,814,350);
    await tap(mobile,26,780,350);
    assert.equal((await state(mobile)).screen,'title','taps beside the tutorial plate are ignored');
    await tap(mobile,195,809,350);
    assert.equal((await state(mobile)).screen,'tutorial');
    await tap(mobile,38,36,350);
    assert.equal((await state(mobile)).screen,'title');
    await mobile.close();
  }
  assert.deepEqual(errors,[]);
  console.log('PASS: title, unavailable campaign, reflections, rapid entry, home/resume, leak/success resume, skip/replay, mute, reduced motion and mobile layouts');
} finally { await browser.close(); }
