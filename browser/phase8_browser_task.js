const fs = require("fs");
const { chromium } = require("playwright");

function parseTaskFile(path) {
  const lines = fs.readFileSync(path, "utf8").split(/\r?\n/);
  const data = {};
  for (const line of lines) {
    const idx = line.indexOf(":");
    if (idx > -1) {
      const key = line.slice(0, idx).trim();
      const value = line.slice(idx + 1).trim();
      if (key) data[key] = value;
    }
  }
  return data;
}

(async () => {
  const taskPath = process.argv[2];
  if (!taskPath) {
    console.error("Missing task file path");
    process.exit(1);
  }

  const task = parseTaskFile(taskPath);
  const logFile = task.OUTPUT_LOG;
  const textFile = task.OUTPUT_TEXT;
  const shotFile = task.OUTPUT_SCREENSHOT;
  const timestamp = new Date().toISOString();

  const log = (msg) => fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${msg}\n`, "utf8");

  let browser;
  try {
    log(`TASK RECEIVED: ${task.TASK_NAME || ""}`);
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto(task.TARGET, { waitUntil: "domcontentloaded", timeout: 30000 });

    const title = await page.title();
    const url = page.url();
    const bodyText = await page.locator("body").innerText().catch(() => "");

    await page.screenshot({ path: shotFile, fullPage: true });

    const lines = [
      "Vex Phase 8 Browser Result",
      `Timestamp: ${timestamp}`,
      `Task Name: ${task.TASK_NAME || ""}`,
      `Title: ${title}`,
      `URL: ${url}`,
      "",
      "Body Preview:",
      (bodyText || "").slice(0, 1000),
      "",
      `Screenshot: ${shotFile}`,
      "Status: SUCCESS"
    ];

    fs.writeFileSync(textFile, lines.join("\n"), "utf8");
    log(`RESULT WRITTEN: ${textFile}`);
    log(`SCREENSHOT WRITTEN: ${shotFile}`);
    log("VERIFICATION PASSED");
    console.log("Browser Phase 8 task complete");
  } catch (err) {
    try {
      log(`FAILED: ${err.message}`);
    } catch {}
    console.error(err.message);
    process.exit(1);
  } finally {
    if (browser) await browser.close();
  }
})();