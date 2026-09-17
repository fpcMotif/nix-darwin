// Full-page and per-screen captures of a running page, for the capture loop.
// Env: URL (required), NAME (default "page"), OUT (default "./captures"),
//      WIDTHS (default "1440,390"), CHANNEL (e.g. "chrome" to use system Chrome),
//      PW (path to a playwright or @playwright/test package; default resolves from cwd).
// Writes: <NAME>-<width>-full.png, <NAME>-<width>-NN.png (one per screen), <NAME>-log.json.
import { createRequire } from "node:module";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

const require = createRequire(path.join(process.cwd(), "package.json"));
const pw = require(process.env.PW || "@playwright/test");
const url = process.env.URL;
if (!url) throw new Error("URL is required");
const name = process.env.NAME || "page";
const out = process.env.OUT || "./captures";
const widths = (process.env.WIDTHS || "1440,390").split(",").map(Number);
mkdirSync(out, { recursive: true });

const browser = await pw.chromium.launch(process.env.CHANNEL ? { channel: process.env.CHANNEL } : {});
const log = { url, errors: [], failed: [], pages: [] };

for (const width of widths) {
  const height = width >= 1024 ? 900 : 844;
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => log.errors.push(String(e)));
  page.on("console", (m) => m.type() === "error" && log.errors.push(m.text()));
  page.on("response", (r) => r.status() >= 400 && log.failed.push(`${r.status()} ${r.url()}`));
  await page.goto(url, { waitUntil: "networkidle" });
  await page.waitForTimeout(600);
  const total = await page.evaluate(() => document.documentElement.scrollHeight);
  let screen = 0;
  for (let y = 0; y < total; y += Math.floor(height * 0.9)) {
    await page.evaluate((y) => window.scrollTo(0, y), y);
    await page.waitForTimeout(350);
    await page.screenshot({ path: path.join(out, `${name}-${width}-${String(screen).padStart(2, "0")}.png`) });
    screen += 1;
  }
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(out, `${name}-${width}-full.png`), fullPage: true });
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  log.pages.push({ width, height: total, screens: screen, horizontalOverflow: overflow });
  await ctx.close();
}

await browser.close();
writeFileSync(path.join(out, `${name}-log.json`), JSON.stringify(log, null, 2));
console.log(JSON.stringify(log, null, 2));
