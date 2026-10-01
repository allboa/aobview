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
const el = (page) => page.evaluateHandle(() => document.querySelector("[data-aob-scene]:not(script)"));
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
async function click(page, s) {
  const at = await screen(page, s.click);
  if (s.shift) await page.keyboard.down("Shift");
  await page.mouse.click(at.x, at.y);
  if (s.shift) await page.keyboard.up("Shift");
  await sleep(400);
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
  s = await step(`${tag}-4`);
  await page.keyboard.press("Escape");
  await sleep(300);
  if ((await ds(page)).aobSelection) { await page.keyboard.press("Escape"); await sleep(300); }
  console.log(tag, "Escape:", JSON.stringify((await ds(page)).aobSelection));
  reply(`${tag}-4`, { selection: (await ds(page)).aobSelection ?? "" });
  if (tag === "3031") {
    await page.evaluate(() => { window.__before = 1; });
    s = await step("3031-5");
    await page.waitForFunction(() => window.__before === undefined, null, { timeout: 30000 });
    await ready(page);
    const d = await ds(page);
    console.log("3031 reloaded; layers", d.aobSelectable, "cameraKept", d.aobCameraKept, "tabs", pages());
    reply("3031-5", { cameraKept: d.aobCameraKept ?? null, tabs: pages() });
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
