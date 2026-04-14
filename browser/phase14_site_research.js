const { chromium } = require("playwright");
const fs = require("fs");

(async () => {
  const url = process.argv[2];
  const output = process.argv[3];

  if (!url || !output) {
    console.log("Missing arguments");
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });

    const title = await page.title();
    const h1 = await page.locator("h1").first().textContent().catch(() => "");
    const bodyText = await page.locator("body").innerText().catch(() => "");
    const preview = bodyText.substring(0, 500);

    const emailMatch = bodyText.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
    const phoneMatch = bodyText.match(/\+?\d[\d\s\-()]{7,}/);

    const email = emailMatch ? emailMatch[0] : "Not found";
    const phone = phoneMatch ? phoneMatch[0] : "Not found";

    const screenshot = output.replace(".txt", ".png");
    await page.screenshot({ path: screenshot, fullPage: true });

    const result = [
      "Vex Phase 14 Site Report",
      `URL: ${url}`,
      `Title: ${title}`,
      `H1: ${h1}`,
      "",
      "Preview:",
      preview,
      "",
      `Email: ${email}`,
      `Phone: ${phone}`,
      "",
      `Screenshot: ${screenshot}`,
      "Status: SUCCESS"
    ].join("\n");

    fs.writeFileSync(output, result, "utf8");
  } catch (err) {
    fs.writeFileSync(output, "FAILED: " + err.message, "utf8");
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
