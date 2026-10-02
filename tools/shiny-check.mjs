// The page side of tools/shiny-check.R (see there): opens the app in
// headless Chromium, waits for the view, clicks the stations and checks that
// the selection comes back through Shiny's input values to R and out again
// as text, renders again with a selection and checks that R's selection is
// cleared, then selects on the new view and clears with Escape.
//
//   node tools/shiny-check.mjs http://127.0.0.1:<port> [screenshot.png]
//
// Needs playwright-core; set CHROMIUM_PATH to use a specific executable.
import { chromium } from "playwright-core";
import assert from "node:assert/strict";

const [url, shot] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined,
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1000, height: 900 }, colorScheme: "light" });
  page.on("pageerror", (e) => errors.push(String(e)));
  for (let i = 0; i < 60; i++) {
    try { await page.goto(url); break; } catch (e) { await page.waitForTimeout(1000); }
  }
  const ready = () => page.waitForFunction(() => {
    const c = document.getElementById("map");
    return c && c.dataset.aobStatus === "ready" && c.dataset.aobLink === "ready" && c.aob;
  }, null, { timeout: 60000 });
  await ready();
  const ds = await page.evaluate(() => ({ ...document.getElementById("map").dataset }));
  assert.deepEqual(ds.aobSelectable.split(",").sort(), ["bases", "coast"]);
  console.log(`ok   the view draws in the app; selectable layers: ${ds.aobSelectable}`);
  const targets = JSON.parse(await page.textContent("#targets"));
  const screen = (xy) => page.evaluate(([x, y]) => {
    const c = document.getElementById("map");
    const r = c.querySelector(".aob-canvas").getBoundingClientRect();
    const v = c.aob.view();
    const k = Math.pow(2, v.zoom);
    return [r.left + r.width / 2 + (x - v.target[0]) * k, r.top + r.height / 2 - (y - v.target[1]) * k];
  }, xy);
  const picked = () => page.textContent("#picked");
  const until = async (re) => {
    await page.waitForFunction((src) => new RegExp(src).test(document.getElementById("picked").textContent),
      re.source, { timeout: 15000 });
    return picked();
  };
  await page.waitForTimeout(400);
  const [dx, dy] = await screen(targets[1]);
  await page.mouse.click(dx, dy);
  let t = await until(/bases=Davis$/);
  assert.match(t, /^trigger=click; layers=bases; bases=Davis$/);
  console.log(`ok   a click arrives in R as input$map_aob_select: ${t}`);
  await page.waitForTimeout(400);
  const [mx, my] = await screen(targets[2]);
  await page.keyboard.down("Shift");
  await page.mouse.click(mx, my);
  await page.keyboard.up("Shift");
  t = await until(/bases=Davis,Mawson$/);
  assert.match(t, /^trigger=toggle; layers=bases; bases=Davis,Mawson$/);
  console.log(`ok   Shift-click adds: ${t}`);
  await page.waitForFunction(() => /camera=4 extent values/.test(document.getElementById("camera").textContent),
    null, { timeout: 15000 });
  console.log("ok   the settled camera arrives as input$map_aob_view");
  if (shot) await page.screenshot({ path: shot, fullPage: true });
  // Render again with two stations selected: R's selection is cleared by
  // the render itself, with no message from the page.
  await page.click("#again");
  t = await until(/^trigger=none; layers=; bases=$/);
  console.log(`ok   a new render clears the selection in R: ${t}`);
  await ready();
  await page.waitForTimeout(400);
  const [cx, cy] = await screen(targets[0]);
  await page.mouse.click(cx, cy);
  t = await until(/bases=Casey$/);
  assert.match(t, /^trigger=click; layers=bases; bases=Casey$/);
  console.log(`ok   after a new render the selection works on the new view: ${t}`);
  await page.waitForTimeout(400);
  await page.keyboard.press("Escape"); // closes Casey's popup
  await page.waitForTimeout(300);
  await page.keyboard.press("Escape");
  t = await until(/trigger=clear/);
  assert.match(t, /^trigger=clear; layers=; bases=$/);
  console.log(`ok   Escape clears: ${t}`);
  assert.deepEqual(errors, []);
  console.log("done");
} finally {
  await browser.close();
}
