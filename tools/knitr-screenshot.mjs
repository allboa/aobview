// Headless screenshot of a knitted document with views (decision 0009).
//
//   Rscript -e 'rmarkdown::render("tools/knitr-two-views.Rmd")'
//   CHROMIUM_PATH=... node tools/knitr-screenshot.mjs \
//     "$PWD/tools/knitr-two-views.html" tools/screenshots/knitr-two-views-light.png light
//
// Waits for every .aob-fragment to be drawn, prints each one's status,
// size, theme and layers, how many scripts carry the renderer, and the
// page's errors, then writes a full-page PNG. Needs playwright-core.
import { chromium } from "playwright-core";
const [file, out, scheme = "light"] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH,
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: 1000, height: 900 }, colorScheme: scheme });
const logs = [];
page.on("console", (m) => { if (m.type() === "error") logs.push(m.text()); });
page.on("pageerror", (e) => logs.push(String(e)));
await page.goto("file://" + file);
await page.waitForFunction(() => { const f = [...document.querySelectorAll(".aob-fragment")];
  return f.length && f.every((e) => e.dataset.aobStatus === "ready" || e.dataset.aobStatus === "error"); }, null, { timeout: 90000 });
await page.waitForTimeout(1500);
const info = await page.evaluate(() => [...document.querySelectorAll(".aob-fragment")].map((e) => ({
  status: e.dataset.aobStatus, errors: e.dataset.aobErrors || null, theme: e.dataset.theme || "auto",
  size: [e.clientWidth, e.clientHeight], layers: [...e.querySelectorAll(".aob-name")].map((n) => n.textContent),
  status_line: e.querySelector(".aob-status") ? e.querySelector(".aob-status").textContent : null })));
console.log(JSON.stringify({ info, renderers: await page.evaluate(() => [...document.scripts].filter((s) => s.textContent.includes("aob-renderer 0.0") || (s.src || "").includes("aob-renderer")).length), logs }, null, 1));
await page.screenshot({ path: out, fullPage: true });
await browser.close();
