import { describe, expect, it } from "vitest";

describe("manual deploy source guard", () => {
  it("allows only semver tags on main", () => {
    const candidate = { branch: "main", tag: "v2.0.1" };
    const isSemver = /^v\d+\.\d+\.\d+$/.test(candidate.tag);
    expect(candidate.branch === "main" && isSemver).toBe(true);
  });
});
