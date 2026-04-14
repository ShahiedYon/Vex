const { chromium } = require("playwright");
const fs = require("fs");

(async () => {
  const logFile = "C:\\Users\\yonsh\\Vex\\logs\\browser-test.log";
  const outFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-result.txt";
  const screenshotFile = "C:\\Users\\yonsh\\Vex\\workspace\\browser-shot.png";
  const timestamp = new Date().toISOString();

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
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
    fs.appendFileSync(logFile, `[${timestamp}] Browser test succeeded\n`, "utf8");

    console.log("Browser test complete");
    console.log(outFile);
    console.log(screenshotFile);
  } catch (err) {
    fs.appendFileSync(logFile, `[${timestamp}] Browser test failed: ${err.message}\n`, "utf8");
    console.error(err.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
