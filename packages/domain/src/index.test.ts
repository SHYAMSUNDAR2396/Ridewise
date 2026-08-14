/// <reference types="vitest" />
import { describe, it, expect } from "vitest";
import { calculateTargetSeconds } from "./index";

describe("calculateTargetSeconds", () => {
  it("keeps a ten percent buffer, bounded between one and three minutes", () => {
    expect(calculateTargetSeconds(900)).toBe(810);
    expect(calculateTargetSeconds(300)).toBe(240);
    expect(calculateTargetSeconds(3600)).toBe(3420);
  });
});
