import { segmentAt } from "../src/features/capsules/use-segment-queue";

const segments = [
  { index: 0, url: "a.mp3", durationSeconds: 10 },
  { index: 1, url: "b.mp3", durationSeconds: 20 },
  { index: 2, url: "c.mp3", durationSeconds: 30 },
];

describe("segmentAt", () => {
  it("resolves a position inside the first segment", () => {
    expect(segmentAt(segments, 4)).toEqual({ index: 0, offsetSeconds: 4 });
  });

  it("resolves a position inside a later segment", () => {
    expect(segmentAt(segments, 25)).toEqual({ index: 1, offsetSeconds: 15 });
  });

  it("clamps a position past the end to the final segment", () => {
    expect(segmentAt(segments, 999)).toEqual({ index: 2, offsetSeconds: 30 });
  });

  it("clamps a negative position to the start", () => {
    expect(segmentAt(segments, -5)).toEqual({ index: 0, offsetSeconds: 0 });
  });
});
