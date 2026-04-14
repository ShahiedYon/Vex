const { chromium } = require("playwright");
const fs = require("fs");

(async () => {
  const logFile = "C:\\Users\\yonsh\\Vex\\logs\\browser-test.log";
  const outFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-result.txt";
  const screenshotFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-shot.png";
  const timestamp = new Date().toISOString();

  const appendLog = (msg) => fs.appendFileSync(logFile, `[${timestamp}] ${msg}\n`, "utf8");

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto("https://example.com", { waitUntil: "domcontentloaded", timeout: 30000 });

    const title = await page.title();
    const url = page.url();

    await page.screenshot({ path: screenshotFile, fullPage: true });

    const lines = [
      "Vex Browser Test Result",
      `Timestamp: ${timestamp}`,
      `Title: ${title}`,
      `URL: ${url}`,
      `Screenshot: ${screenshotFile}`,
      "Status: SUCCESS"
    ];

    fs.writeFileSync(outFile, lines.join("\n"), "utf8");
    appendLog("Browser test succeeded");
    console.log("Browser test complete");
  } catch (err) {
    appendLog(`Browser test failed: ${err.message}`);
    console.error(err.message);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();
