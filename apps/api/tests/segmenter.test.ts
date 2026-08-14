import { describe, it, expect } from "vitest";
import { splitIntoSegments } from "../src/services/segmenter";

describe("splitIntoSegments", () => {
  it("packs whole sentences up to the limit", () => {
    expect(splitIntoSegments("One. Two. Three.", 10)).toEqual(["One. Two.", "Three."]);
  });

  it("returns a single segment when everything fits", () => {
    expect(splitIntoSegments("Only one sentence here.", 8000)).toEqual([
      "Only one sentence here.",
    ]);
  });

  it("never splits inside a sentence, even when that sentence exceeds the limit", () => {
    const long = `${"word ".repeat(20).trim()}.`;
    const segments = splitIntoSegments(long, 10);
    expect(segments).toEqual([long]);
  });

  it("returns an empty array for blank input", () => {
    expect(splitIntoSegments("   ", 8000)).toEqual([]);
  });
});
