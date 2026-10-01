// Headless check that a popup shows a feature's attributes in an EPSG:3031
// view: opens zcol-popup-in-3031.html (from tools/write-views.R) in
// headless Chromium, selects the first station with a click, and checks
// that the popup lists its columns and values as text.
//
//   Rscript tools/write-views.R <dir>
//   node tools/popup-check.mjs <dir>
//
// Needs playwright-core (npm install playwright-core) and a Chromium it can
// find; set CHROMIUM_PATH to use a specific executable.
import { chromium } from "playwright-core";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const dir = process.argv[2];
if (!dir) {
  console.error("usage: node tools/popup-check.mjs <dir-with-views>");
  process.exit(2);
}
const want = [
  ["name", "Casey"],
  ["operator", "Australia"],
  ["established", "1969-02-01"],
  ["elevation_m", "40"],
];

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH || undefined,
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
let failed = 0;
for (const scheme of ["light", "dark"]) {
  const ctx = await browser.newContext({ viewport: { width: 1100, height: 760 }, colorScheme: scheme });
  const page = await ctx.newPage();
  await page.goto(pathToFileURL(resolve(dir, "zcol-popup-in-3031.html")).href);
  const status = await page
    .waitForFunction(() => {
      const s = document.querySelector("[data-aob-scene]:not(script)");
      return s && ["ready", "error"].includes(s.dataset.aobStatus) && s.dataset.aobStatus;
    }, null, { timeout: 60000 })
    .then((h) => h.jsonValue())
    .catch(() => "timeout");
  if (status !== "ready") {
    console.log(`FAIL ${scheme}: page ${status}`);
    failed++;
    await ctx.close();
    continue;
  }
  const at = await page.evaluate(stationPoint);
  await page.mouse.click(at.x, at.y);
  const rows = await page
    .waitForFunction(() => {
      const p = document.querySelector(".aob-popup");
      if (!p || p.hidden) return null;
      const dt = [...p.querySelectorAll("dt")].map((e) => e.textContent);
      const dd = [...p.querySelectorAll("dd")].map((e) => e.textContent);
      return { layer: p.dataset.aobLayer, row: p.dataset.aobRow, rows: dt.map((k, i) => [k, dd[i]]) };
    }, null, { timeout: 10000 })
    .then((h) => h.jsonValue())
    .catch(() => null);
  const ok = rows && rows.layer === "stations" && rows.row === "0" &&
    JSON.stringify(rows.rows) === JSON.stringify(want);
  if (!ok) failed++;
  console.log(`${ok ? "ok  " : "FAIL"} ${scheme}: ${JSON.stringify(rows)}`);
  await ctx.close();
}
await browser.close();
process.exit(failed ? 1 : 0);

// In the page: the screen position of the first feature of layer
// "stations" (a point layer), in the orthographic view.
function stationPoint() {
  const c = document.querySelector("[data-aob-scene]:not(script)");
  const h = c.aob;
  const L = h.scene.layers.find((l) => l.id === "stations");
  const ref = h.scene.data[L.data];
  let g = h.tables[L.data].getChild(ref.geometry.column).get(0);
  while (g && typeof g.get === "function" && typeof g.get(0) !== "number") g = g.get(0);
  let [x, y] = [g.get(0), g.get(1)];
  if (ref.origin_subtracted) [x, y] = [x + h.scene.view.local_origin[0], y + h.scene.view.local_origin[1]];
  const r = c.querySelector(".aob-canvas").getBoundingClientRect();
  const v = h.view();
  const k = Math.pow(2, v.zoom);
  return { x: r.left + r.width / 2 + (x - v.target[0]) * k, y: r.top + r.height / 2 - (y - v.target[1]) * k };
}
