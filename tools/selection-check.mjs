// The page side of tools/selection-check.R (see there): reads R's step
// files, drives headless Chromium, writes back what the page shows, and
// saves screenshots of a selection.
//
// Needs playwright-core (npm install playwright-core) and a Chromium it can
// find; set CHROMIUM_PATH to use a specific executable.
import { chromium } from "playwright-core";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const dir = process.argv[2];
const shots = process.argv[3];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function step(name) {
  const f = `${dir}/${name}.json`;
  for (let i = 0; i < 1800 && !existsSync(f); i++) await sleep(100);
  await sleep(100);
  return JSON.parse(readFileSync(f, "utf8"));
}
const reply = (name, x) => writeFileSync(`${dir}/${name}-page.json`, JSON.stringify(x));
const ds = (page) => page.evaluate(() => ({ ...document.querySelector("[data-aob-scene]:not(script)").dataset }));
async function ready(page) {
  await page.waitForFunction(() => {
    const c = document.querySelector("[data-aob-scene]:not(script)");
    return c && c.dataset.aobStatus === "ready" && c.dataset.aobLink === "ready";
  }, null, { timeout: 60000 });
}
async function screen(page, xy) {
  return page.evaluate(([x, y]) => {
    const c = document.querySelector("[data-aob-scene]:not(script)");
    const r = c.querySelector(".aob-canvas").getBoundingClientRect();
    const v = c.aob.view();
    const k = Math.pow(2, v.zoom);
    return { x: r.left + r.width / 2 + (x - v.target[0]) * k, y: r.top + r.height / 2 - (y - v.target[1]) * k };
  }, xy);
}
const selectionNow = (page) => page.evaluate(
  () => document.querySelector("[data-aob-scene]:not(script)").dataset.aobSelection ?? "");
// Wait until the page's selection differs from `before`.
async function selectionChange(page, before, timeout = 10000) {
  await page.waitForFunction((b) => {
    const c = document.querySelector("[data-aob-scene]:not(script)");
    return (c.dataset.aobSelection ?? "") !== b;
  }, before, { timeout });
}
async function click(page, s) {
  const at = await screen(page, s.click);
  const before = await selectionNow(page);
  if (s.shift) await page.keyboard.down("Shift");
  await page.mouse.click(at.x, at.y);
  if (s.shift) await page.keyboard.up("Shift");
  await selectionChange(page, before);
}
// Drag the map by (dx, dy) pixels from the canvas centre, then wait for the
// view to settle (the page sends `view` 250 ms after the camera stops).
async function pan(page, dx, dy) {
  const r = await page.evaluate(() => {
    const b = document.querySelector("[data-aob-scene]:not(script) .aob-canvas").getBoundingClientRect();
    return { x: b.left + b.width / 2, y: b.top + b.height / 2 };
  });
  await page.mouse.move(r.x, r.y);
  await page.mouse.down();
  // Two quick moves: a drag that pauses longer than the settle time mid-way is two
  // settled views, by design, and software rendering can pause that long.
  await page.mouse.move(r.x + dx / 2, r.y + dy / 2);
  await page.mouse.move(r.x + dx, r.y + dy);
  await page.mouse.up();
  await sleep(1500);
}
const popupText = (page) => page.evaluate(() => {
  const p = document.querySelector(".aob-popup");
  return p && !p.hidden ? [...p.querySelectorAll("dd")].map((e) => e.textContent)[0] : null;
});

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH || undefined,
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
for (const [tag, scheme] of [["3031", "light"], ["3857", "dark"]]) {
  const ctx = await browser.newContext({ viewport: { width: 1100, height: 760 }, colorScheme: scheme });
  const page = await ctx.newPage();
  const pages = () => ctx.pages().length;
  let s = await step(`${tag}-1`);
  await page.goto(s.url);
  await ready(page);
  console.log(tag, "ready; selectable", (await ds(page)).aobSelectable);
  await click(page, s);
  await page.waitForFunction(() => {
    const p = document.querySelector(".aob-popup");
    return p && !p.hidden && p.querySelector("dd");
  }, null, { timeout: 10000 }).catch(() => null);
  reply(`${tag}-1`, { popup: await popupText(page), selection: (await ds(page)).aobSelection });
  console.log(tag, "click:", JSON.stringify({ popup: await popupText(page), sel: (await ds(page)).aobSelection }));
  s = await step(`${tag}-2`);
  await click(page, s);
  console.log(tag, "shift-click:", (await ds(page)).aobSelection);
  await page.screenshot({ path: `${shots}/selection-${tag}-${scheme}.png` });
  s = await step(`${tag}-3`);
  await click(page, s);
  console.log(tag, "shift-click again:", (await ds(page)).aobSelection);
  // A click on empty map clears.
  s = await step(`${tag}-3e`);
  await click(page, s);
  console.log(tag, "click on empty map:", JSON.stringify(await selectionNow(page)));
  reply(`${tag}-3e`, { selection: await selectionNow(page) });
  s = await step(`${tag}-3f`);
  await click(page, s);
  s = await step(`${tag}-4`);
  const before = await selectionNow(page);
  // The first Escape may only close the popup; a second clears.
  await page.keyboard.press("Escape");
  if (!(await selectionChange(page, before, 1500).then(() => true, () => false))) {
    await page.keyboard.press("Escape");
    await selectionChange(page, before).catch(() => null);
  }
  console.log(tag, "Escape:", JSON.stringify(await selectionNow(page)));
  reply(`${tag}-4`, { selection: await selectionNow(page) });
  // One settled pan: one `view` message.
  s = await step(`${tag}-pan`);
  await pan(page, s.dx, s.dy);
  console.log(tag, "panned by", s.dx, s.dy);
  reply(`${tag}-pan`, { panned: true });
  if (tag === "3031") {
    await page.evaluate(() => { window.__before = 1; });
    s = await step("3031-5");
    await page.waitForFunction(() => window.__before === undefined, null, { timeout: 30000 });
    await ready(page);
    const d = await ds(page);
    console.log("3031 reloaded; layers", d.aobSelectable, "cameraKept", d.aobCameraKept, "tabs", pages());
    reply("3031-5", { cameraKept: d.aobCameraKept ?? null, tabs: pages() });
    // print() of the view, with this page connected: R asks to open
    // nothing. Any URL R asks to open is opened here, as a browser would.
    s = await step("3031-p");
    if (existsSync(`${dir}/open.json`)) {
      const extra = await ctx.newPage();
      await extra.goto(JSON.parse(readFileSync(`${dir}/open.json`, "utf8")).url);
    }
    console.log("3031 after print: tabs", pages());
    reply("3031-p", { tabs: pages() });
    s = await step("3031-6");
    await click(page, s);
    console.log("3031 after reload click:", (await ds(page)).aobSelection);
    s = await step("3031-7");
    await page.waitForFunction(() => {
      const c = document.querySelector("[data-aob-scene]:not(script)");
      return c.dataset.aobLink !== "ready";
    }, null, { timeout: 30000 });
    await sleep(500);
    const note = await page.evaluate(() => [...document.querySelectorAll("*")]
      .map((e) => e.childElementCount === 0 ? e.textContent : "").find((t) => /Not connected/.test(t)) ?? null);
    const link = (await ds(page)).aobLink;
    console.log("3031 after stop: link", link, "note", note);
    await page.screenshot({ path: `${shots}/stopped-3031-${scheme}.png` });
    reply("3031-7", { link: link === "connecting" || link === "closed" ? "closed" : link, note });
  }
  await ctx.close();
}
await step("done");
await browser.close();
