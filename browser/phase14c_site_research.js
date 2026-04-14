const { chromium } = require("playwright");
const fs = require("fs");

function uniq(values) {
  return [...new Set(values.filter(Boolean))];
}

function absolutize(baseUrl, href) {
  try {
    return new URL(href, baseUrl).toString();
  } catch {
    return null;
  }
}

function extractEmails(text) {
  const matches = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi) || [];
  return uniq(matches);
}

function extractPhones(text) {
  const matches = text.match(/\+?\d[\d\s\-()]{7,}\d/g) || [];
  return uniq(matches.map(v => v.trim()));
}

function normalizeSocial(url) {
  if (!url) return null;
  const lower = url.toLowerCase();
  if (
    lower.includes("linkedin.com") ||
    lower.includes("facebook.com") ||
    lower.includes("instagram.com") ||
    lower.includes("x.com") ||
    lower.includes("twitter.com") ||
    lower.includes("youtube.com") ||
    lower.includes("tiktok.com")
  ) {
    return url;
  }
  return null;
}

async function collectPageData(page, pageUrl) {
  await page.goto(pageUrl, { waitUntil: "domcontentloaded", timeout: 25000 });

  const title = await page.title().catch(() => "");
  const h1 = await page.locator("h1").first().textContent().catch(() => "");
  const bodyText = await page.locator("body").innerText().catch(() => "");
  const preview = (bodyText || "").substring(0, 1000);

  const links = await page.locator("a").evaluateAll((els) =>
    els.map((a) => ({
      href: a.getAttribute("href") || "",
      text: (a.textContent || "").trim()
    }))
  ).catch(() => []);

  const absoluteLinks = [];
  const mailtos = [];
  const tels = [];
  const socials = [];
  const candidatePages = [];

  for (const link of links) {
    const rawHref = link.href || "";
    const text = (link.text || "").toLowerCase();

    if (rawHref.toLowerCase().startsWith("mailto:")) {
      mailtos.push(rawHref.replace(/^mailto:/i, "").trim());
      continue;
    }

    if (rawHref.toLowerCase().startsWith("tel:")) {
      tels.push(rawHref.replace(/^tel:/i, "").trim());
      continue;
    }

    const abs = absolutize(pageUrl, rawHref);
    if (!abs) continue;

    absoluteLinks.push(abs);

    const social = normalizeSocial(abs);
    if (social) {
      socials.push(social);
    }

    const lowerAbs = abs.toLowerCase();
    if (
      text.includes("contact") ||
      text.includes("about") ||
      lowerAbs.includes("/contact") ||
      lowerAbs.includes("/about") ||
      lowerAbs.includes("contact-us") ||
      lowerAbs.includes("about-us")
    ) {
      candidatePages.push(abs);
    }
  }

  return {
    pageUrl,
    title,
    h1: h1 || "",
    preview,
    emails: extractEmails(bodyText).concat(mailtos),
    phones: extractPhones(bodyText).concat(tels),
    socials,
    candidatePages
  };
}

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
    const main = await collectPageData(page, url);

    const candidatePages = uniq(main.candidatePages).slice(0, 5);
    const subPageResults = [];

    for (const candidate of candidatePages) {
      try {
        const data = await collectPageData(page, candidate);
        subPageResults.push(data);
      } catch {
      }
    }

    const allEmails = uniq([
      ...main.emails,
      ...subPageResults.flatMap(p => p.emails || [])
    ]);

    const allPhones = uniq([
      ...main.phones,
      ...subPageResults.flatMap(p => p.phones || [])
    ]);

    const allSocials = uniq([
      ...main.socials,
      ...subPageResults.flatMap(p => p.socials || [])
    ]);

    const discoveredPages = uniq([
      ...candidatePages
    ]);

    const screenshot = output.replace(".txt", ".png");
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 25000 });
    await page.screenshot({ path: screenshot, fullPage: true });

    const resultLines = [];
    resultLines.push("Vex Phase 14c Site Report");
    resultLines.push(`URL: ${url}`);
    resultLines.push(`Title: ${main.title}`);
    resultLines.push(`H1: ${main.h1}`);
    resultLines.push("");
    resultLines.push("Landing Page Preview:");
    resultLines.push(main.preview);
    resultLines.push("");

    resultLines.push("Discovered Contact/About Pages:");
    if (discoveredPages.length) {
      for (const p of discoveredPages) resultLines.push(`- ${p}`);
    } else {
      resultLines.push("- None found");
    }
    resultLines.push("");

    resultLines.push("Emails:");
    if (allEmails.length) {
      for (const e of allEmails) resultLines.push(`- ${e}`);
    } else {
      resultLines.push("- Not found");
    }
    resultLines.push("");

    resultLines.push("Phones:");
    if (allPhones.length) {
      for (const p of allPhones) resultLines.push(`- ${p}`);
    } else {
      resultLines.push("- Not found");
    }
    resultLines.push("");

    resultLines.push("Social Links:");
    if (allSocials.length) {
      for (const s of allSocials) resultLines.push(`- ${s}`);
    } else {
      resultLines.push("- Not found");
    }
    resultLines.push("");

    resultLines.push(`Screenshot: ${screenshot}`);
    resultLines.push("Status: SUCCESS");

    fs.writeFileSync(output, resultLines.join("\n"), "utf8");
  } catch (err) {
    fs.writeFileSync(output, "FAILED: " + err.message, "utf8");
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
