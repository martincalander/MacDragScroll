#!/usr/bin/env node

import { mkdir, mkdtemp, rename, rm } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const source = path.join(root, "docs/assets/source/readme-demos.html");
const output = path.join(root, "docs/assets");
const playwrightPath = process.env.PLAYWRIGHT_PATH;

if (!playwrightPath) {
  throw new Error("Set PLAYWRIGHT_PATH to a Playwright package directory.");
}

const { chromium } = await import(pathToFileURL(path.join(playwrightPath, "index.mjs")));
const demos = [
  { name: "install", seconds: 4.8, output: "mac-drag-scroll-install-demo.gif" },
  { name: "permissions", seconds: 4.8, output: "mac-drag-scroll-permission-demo.gif" },
  { name: "usage", seconds: 5.4, output: "mac-drag-scroll-usage-demo.gif" },
];
const fps = 10;
const stagingRoot = await mkdtemp(path.join(output, ".readme-demo-render-"));
const framesRoot = path.join(stagingRoot, "frames");
const stagedOutput = path.join(stagingRoot, "output");
let browser;

try {
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(source).href);
  await page.evaluate(() => document.fonts.ready);

  await mkdir(framesRoot, { recursive: true });
  await mkdir(stagedOutput, { recursive: true });

  for (const demo of demos) {
    const directory = path.join(framesRoot, demo.name);
    const count = Math.round(demo.seconds * fps);
    await mkdir(directory, { recursive: true });

    for (let index = 0; index < count; index += 1) {
      const progress = index / (count - 1);
      await page.evaluate(([name, value]) => window.renderFrame(name, value), [demo.name, progress]);
      await page.screenshot({
        path: path.join(directory, `${String(index).padStart(4, "0")}.png`),
        animations: "disabled",
      });
    }

    const input = path.join(directory, "%04d.png");
    const destination = path.join(stagedOutput, demo.output);
    execFileSync("ffmpeg", [
      "-y", "-hide_banner", "-loglevel", "error",
      "-framerate", String(fps), "-i", input,
      "-filter_complex",
      "[0:v]split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle[v]",
      "-map", "[v]", "-loop", "0", destination,
    ]);
  }

  for (const demo of demos) {
    await rename(
      path.join(stagedOutput, demo.output),
      path.join(output, demo.output),
    );
  }
} finally {
  try {
    await browser?.close();
  } finally {
    await rm(stagingRoot, { recursive: true, force: true });
  }
}
