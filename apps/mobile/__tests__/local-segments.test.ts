import { isFullyDownloaded, type StoredCapsule } from "../src/features/capsules/capsule-store";
import { playbackQueueUris } from "../src/features/capsules/download";

const base: StoredCapsule = {
  id: "c1",
  title: "T",
  topic: "Topic",
  language: "en-IN",
  targetSeconds: 60,
  audioSeconds: 60,
  transcript: "Text.",
  segments: [
    { index: 0, url: "file:///docs/capsules/c1/segment-0.wav", durationSeconds: 30 },
    { index: 1, url: "file:///docs/capsules/c1/segment-1.wav", durationSeconds: 30 },
  ],
  createdAt: "2026-10-03T00:00:00.000Z",
  progressSeconds: 0,
  saved: false,
  downloadedSegmentUris: {},
};

describe("capsules made on this phone", () => {
  it("count as downloaded and play from their own files", () => {
    expect(isFullyDownloaded(base)).toBe(true);
    expect(playbackQueueUris(base)).toEqual([
      "file:///docs/capsules/c1/segment-0.wav",
      "file:///docs/capsules/c1/segment-1.wav",
    ]);
  });

  it("still need every remote segment downloaded", () => {
    const remote: StoredCapsule = {
      ...base,
      segments: base.segments.map((segment) => ({ ...segment, url: `https://cdn.example.com/${segment.index}.mp3` })),
    };
    expect(isFullyDownloaded(remote)).toBe(false);
    expect(playbackQueueUris(remote)).toEqual([
      "https://cdn.example.com/0.mp3",
      "https://cdn.example.com/1.mp3",
    ]);
    expect(isFullyDownloaded({ ...remote, downloadedSegmentUris: { 0: "file:///a", 1: "file:///b" } })).toBe(true);
  });
});
