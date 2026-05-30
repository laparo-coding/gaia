import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("format and lint gates", () => {
  it("requires both format and lint checks", () => {
    const workflow = readFileSync(join(process.cwd(), ".github/workflows/ci.yml"), "utf8");

    const hasFormat = workflow.includes("swift format lint");
    const hasLintTarget = workflow.includes("--recursive Sources Tests app/authentication");
    expect(hasFormat && hasLintTarget).toBe(true);
  });
});
