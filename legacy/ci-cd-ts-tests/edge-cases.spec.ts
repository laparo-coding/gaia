import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("CI/CD edge cases", () => {
  it("marks unresolved blocking review comments as blocking", () => {
    const gatesDoc = readFileSync(join(process.cwd(), "docs/ops/ci-cd-quality-gates.md"), "utf8");
    expect(gatesDoc).toContain("zero unresolved blocking comments");
  });
});
