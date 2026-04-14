const fs = require("fs");

const logFile = "C:\\Users\\yonsh\\Vex\\logs\\node-test.log";
const timestamp = new Date().toISOString();

fs.appendFileSync(logFile, `[${timestamp}] Node tool executed successfully\n`);

console.log("Node test complete");
