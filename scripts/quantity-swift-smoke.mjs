/**
 * Compiles Quantity.swift + ios/quantity_smoke.swift when swiftc exists.
 * Skips cleanly on machines without a Swift toolchain (CI/web).
 */
import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const swiftc = spawnSync("swiftc", ["--version"], { encoding: "utf8" });
if (swiftc.error || swiftc.status !== 0) {
  console.log("quantity swift smoke skipped (no swiftc)");
  process.exit(0);
}

const out = join(mkdtempSync(join(tmpdir(), "quantity-smoke-")), "quantity-smoke");
const compile = spawnSync(
  "swiftc",
  [
    "-parse-as-library",
    "ios/Adaptable/Adaptable/Utilities/Quantity.swift",
    "ios/quantity_smoke.swift",
    "-o",
    out,
  ],
  { encoding: "utf8" },
);
if (compile.status !== 0) {
  console.error(compile.stdout);
  console.error(compile.stderr);
  process.exit(compile.status ?? 1);
}

const run = spawnSync(out, { encoding: "utf8" });
process.stdout.write(run.stdout);
process.stderr.write(run.stderr);
process.exit(run.status ?? 1);
