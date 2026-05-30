import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("signing preconditions", () => {
  it("fails early when profile reference is missing", () => {
    const script = readFileSync(join(process.cwd(), "scripts/ci-cd/preflight-check.sh"), "utf8");

    expect(script).toContain("IOS_PROVISIONING_PROFILE_BASE64");
    expect(script).toContain("Preflight failed: missing signing inputs");
  });
});
