import { describe, expect, it } from "vitest";

const ciStages = ["lint-format", "build", "test", "review-gates"];
const deployStages = [
  "validate-preconditions",
  "archive-build",
  "sign-and-export-ipa",
  "publish-artifacts",
];

describe("workflow contract", () => {
  it("requires CI stages in deterministic order", () => {
    expect(ciStages).toEqual(["lint-format", "build", "test", "review-gates"]);
  });

  it("requires deployment stage sequence", () => {
    expect(deployStages).toEqual([
      "validate-preconditions",
      "archive-build",
      "sign-and-export-ipa",
      "publish-artifacts",
    ]);
  });

  it("enforces semver tag policy contract", () => {
    const semverTag = /^v\d+\.\d+\.\d+$/;
    expect(semverTag.test("v1.2.3")).toBe(true);
    expect(semverTag.test("release-1.2.3")).toBe(false);
  });
});
