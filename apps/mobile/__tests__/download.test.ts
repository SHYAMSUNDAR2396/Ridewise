import type { Capsule } from "@commute-capsule/domain";
import { downloadCapsule } from "../src/features/capsules/download";

const mockFetch = jest.fn();

jest.mock("react-native-blob-util", () => ({
  __esModule: true,
  default: {
    fs: {
      dirs: { DocumentDir: "/mock/documents" },
      exists: jest.fn().mockResolvedValue(true),
      unlink: jest.fn().mockResolvedValue(undefined),
    },
    config: () => ({ fetch: (...args: unknown[]) => mockFetch(...args) }),
  },
}));

const capsule: Capsule = {
  id: "capsule-1",
  title: "Test capsule",
  topic: "Testing",
  language: "en-IN",
  targetSeconds: 60,
  audioSeconds: 60,
  transcript: "Text.",
  segments: [
    { index: 0, url: "https://cdn.example.com/segment-0.mp3", durationSeconds: 30 },
    { index: 1, url: "https://cdn.example.com/segment-1.mp3", durationSeconds: 30 },
  ],
  createdAt: "2026-08-14T00:00:00.000Z",
};

describe("downloadCapsule", () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  it("downloads segments independently: a failed segment does not block the others from registering", async () => {
    mockFetch.mockImplementation((_method: string, url: string) => {
      if (url.includes("segment-1")) return Promise.reject(new Error("network error"));
      return Promise.resolve({});
    });

    const onSegmentComplete = jest.fn();
    await expect(downloadCapsule(capsule, onSegmentComplete)).rejects.toThrow();

    expect(onSegmentComplete).toHaveBeenCalledWith(0, expect.stringContaining("segment-0.mp3"));
    expect(onSegmentComplete).toHaveBeenCalledTimes(1);
  });

  it("resolves without error when every segment succeeds", async () => {
    mockFetch.mockResolvedValue({});
    const onSegmentComplete = jest.fn();
    await expect(downloadCapsule(capsule, onSegmentComplete)).resolves.toBeUndefined();
    expect(onSegmentComplete).toHaveBeenCalledTimes(2);
  });
});
