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
try {
  const page = await create();
  const launch = await state(page);
  assert.equal(launch.campaign_available, false);
  await tap(page,195,675); // unavailable campaign
  await tap(page,195,500); // decorative floor
  assert.deepEqual(await state(page), launch);
  assert.equal((await feedback(page)).sound_starts, 0);
  assert.equal((await feedback(page)).lamp_sound_starts, 0);
  await page.screenshot({ path: `${out}/title-reflections-a.png` });
  const wallA = await page.screenshot({clip:{x:6,y:195,width:50,height:220}});
  const floorA = await page.screenshot({clip:{x:24,y:435,width:342,height:186}});
  await page.waitForTimeout(1700);
  await page.screenshot({ path: `${out}/title-reflections-b.png` });
  assert.notDeepEqual(await page.screenshot({clip:{x:6,y:195,width:50,height:220}}), wallA, 'wall reflections move');
  assert.notDeepEqual(await page.screenshot({clip:{x:24,y:435,width:342,height:186}}), floorA, 'glass lighting moves');
  assert.deepEqual(await state(page), launch, 'animation cannot change gameplay');
  // Entry and the lesson OK overlap; a rapid second click must not skip copy.
  await tap(page,195,775,35);
  await tap(page,195,793,35);
  assert.equal((await state(page)).dialogue_visible, true);
  await page.waitForTimeout(300);
  await tap(page,195,793);
  await tap(page,100,214);
  const playing = await state(page);
  await tap(page,38,36,350);
  const home = await state(page);
  assert.equal(home.screen,'title');
  assert.deepEqual(home.corrections, playing.corrections);
  const count = (await feedback(page)).lamp_sound_starts;
  await page.waitForTimeout(700);
  assert.equal((await feedback(page)).lamp_sound_starts,count,'no tutorial lamp sound on title');
  await tap(page,195,775,350);
  const resumed = await state(page);
  assert.deepEqual(resumed, playing, 'continue preserves entire semantic state');
  // Cancel the edge wire, solve, and resume an existing success without a second sting.
  for(let i=0;i<3;i++) await tap(page,100,214);
  await tap(page,195,309);
  const solved = await feedback(page);
  assert.equal(solved.success_count,1);
  await tap(page,38,36,350);
  await tap(page,195,775,350);
  assert.equal((await feedback(page)).sound_starts,solved.sound_starts);
  await tap(page,195,793); // next
  await tap(page,195,793); // blue intro
  await tap(page,195,309);
  await tap(page,195,309);
  await tap(page,195,793); // combined
  await tap(page,195,793);
  for(let i=0;i<3;i++) await tap(page,195,309);
  await tap(page,195,793); // inspection
  await tap(page,195,793);
  await tap(page,195,793);
  await tap(page,195,793); // trap
  await tap(page,195,793);
  assert.equal((await feedback(page)).leak_active,true);
  const leakCount=(await feedback(page)).leak_sound_starts;
  await tap(page,38,36,350);
  assert.equal((await feedback(page)).leak_active,false);
  assert.deepEqual((await feedback(page)).revealed_hidden,{});
  await tap(page,195,775,350);
  assert.equal((await feedback(page)).leak_active,true);
  assert.equal((await feedback(page)).leak_sound_starts,leakCount);
  await tap(page,195,793); // boundary
  await tap(page,195,793);
  await tap(page,100,214);
  await tap(page,195,793);
  await tap(page,195,793);
  await tap(page,290,214);
  await tap(page,290,214);
  await tap(page,195,793); // final
  await tap(page,195,793);
  await tap(page,195,735); // skip
  assert.equal((await state(page)).finished,true);
  await tap(page,195,575,350); // explicit Back to title
  assert.equal((await state(page)).screen,'title');
  await page.screenshot({path:`${out}/title-after-completion.png`});
  await tap(page,195,775,350); // replay
  assert.equal((await state(page)).stage,1);
  assert.equal((await state(page)).dialogue_visible,true);
  assert.equal((await state(page)).finished,false);
  assert.equal((await feedback(page)).leak_active,false);
  // Shared mute across title, tutorial and a browser reload.
  await tap(page,38,36,350);
  await tap(page,325,36);
  assert.equal((await feedback(page)).muted,true);
  await tap(page,195,775,350);
  await tap(page,195,793);
  await tap(page,195,309);
  assert.equal((await feedback(page)).sound_starts,solved.sound_starts+5); // prior safe lessons only, muted replay adds zero
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
  await tap(quiet,195,775,350);
  await tap(quiet,195,793);
  await quiet.waitForTimeout(700);
  assert.equal((await feedback(quiet)).lamp_sound_starts,0);
  await quiet.close();
  for(const [width,height] of [[320,568],[412,915],[844,390]]) {
    const mobile = await create({viewport:{width,height},reducedMotion:'reduce'});
    await mobile.screenshot({path:`${out}/title-${width}x${height}.png`});
    await tap(mobile,195,775,350);
    assert.equal((await state(mobile)).screen,'tutorial');
    await tap(mobile,38,36,350);
    assert.equal((await state(mobile)).screen,'title');
    await mobile.close();
  }
  assert.deepEqual(errors,[]);
  console.log('PASS: title, unavailable campaign, reflections, rapid entry, home/resume, leak/success resume, skip/replay, mute, reduced motion and mobile layouts');
} finally { await browser.close(); }
