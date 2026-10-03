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

import { splitIntoSegments, withRetry } from "./index";

describe("splitIntoSegments", () => {
  it("packs whole sentences up to the limit", () => {
    expect(splitIntoSegments("One. Two. Three.", 10)).toEqual(["One. Two.", "Three."]);
  });

  it("never splits inside an over-long sentence", () => {
    const long = `${"word ".repeat(20).trim()}.`;
    expect(splitIntoSegments(long, 10)).toEqual([long]);
  });

  it("splits Hindi at the danda", () => {
    expect(splitIntoSegments("यह पहला है। यह दूसरा है।", 12)).toEqual(["यह पहला है।", "यह दूसरा है।"]);
  });
});

describe("withRetry", () => {
  it("retries until it succeeds, then rethrows when exhausted", async () => {
    let calls = 0;
    await expect(
      withRetry(async () => {
        calls += 1;
        if (calls < 2) throw new Error("503");
        return "ok";
      }, 3, 1),
    ).resolves.toBe("ok");
    await expect(withRetry(() => Promise.reject(new Error("503")), 2, 1)).rejects.toThrow("503");
  });
});
