const fs = require("fs");

const outFile = "C:\\Users\\yonsh\\Vex\\workspace\\phase8-node-result.txt";
const logFile = "C:\\Users\\yonsh\\Vex\\logs\\phase8-node.log";
const ts = new Date().toISOString();

fs.writeFileSync(
  outFile,
  [
    "Vex Phase 8 Node Result",
    `Timestamp: ${ts}`,
    "Status: SUCCESS",
    "Message: Node handler executed successfully."
  ].join("\n"),
  "utf8"
);

fs.appendFileSync(logFile, `[${ts}] Node handler executed successfully\n`, "utf8");
console.log("Node Phase 8 task complete");