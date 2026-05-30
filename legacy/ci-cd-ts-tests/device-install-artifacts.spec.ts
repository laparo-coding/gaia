import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("device install artifacts", () => {
  it("requires ipa, symbols, and metadata outputs", () => {
    const workflow = readFileSync(
      join(process.cwd(), ".github/workflows/deploy-ipad.yml"),
      "utf8"
    );

    expect(workflow).toContain("artifacts/app.ipa");
    expect(workflow).toContain("artifacts/symbols.dSYM.zip");
    expect(workflow).toContain("artifacts/release.json");
  });
});
