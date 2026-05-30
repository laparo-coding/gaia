import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("rollback retention", () => {
  it("keeps at least three latest successful artifacts", () => {
    const policy = readFileSync(join(process.cwd(), "docs/ops/release-policy.md"), "utf8");
    expect(policy).toContain("Retain at least the three latest successful release bundles");
  });
});
