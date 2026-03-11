import * as os from "os";
import * as process from "process";

// Verify non-root execution
const uid: number = process.getuid?.() ?? -1;
if (uid === 0) {
  console.error(`Container must not run as root (got uid=${uid})`);
  process.exit(1);
}

// Verify Node version matches expected (if provided via env)
const expected: string | undefined = process.env.EXPECTED_VERSION;
if (expected) {
  const actual: string = process.version.replace(/^v/, "");
  if (actual !== expected) {
    console.error(`Version mismatch: expected ${expected}, got ${actual}`);
    process.exit(1);
  }
}

console.log(`Node version: ${process.version}`);
console.log(`Running as uid: ${uid}`);
console.log("All smoke test assertions passed.");
