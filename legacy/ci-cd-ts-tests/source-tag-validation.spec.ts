import { describe, expect, it } from "vitest";

describe("source and tag validation", () => {
  it("rejects non-main branch or non-semver tags", () => {
    const invalidSource = { branch: "feature/x", tag: "1.2.3" };
    const valid =
      invalidSource.branch === "main" &&
      /^v\d+\.\d+\.\d+$/.test(invalidSource.tag);
    expect(valid).toBe(false);
  });
});
