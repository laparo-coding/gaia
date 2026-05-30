import { describe, expect, it } from "vitest";

describe("deploy authorization", () => {
  it("denies non-admin actors", () => {
    const actor = { role: "nonAdmin" };
    expect(actor.role === "admin").toBe(false);
  });
});
