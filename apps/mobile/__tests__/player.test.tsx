import React from "react";
import { render, screen, userEvent, waitFor } from "@testing-library/react-native";
import type { Capsule } from "@commute-capsule/domain";
import { CapsulePlayer } from "../src/features/capsules/player";
import { segmentAt } from "../src/features/capsules/use-segment-queue";
import { useCapsuleStore } from "../src/features/capsules/capsule-store";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest"),
);

// react-native-blob-util and react-native-track-player defaults come from
// jest.setup.js; track-player is overridden below with mocks this file can
// assert against.
const mockSetQueue = jest.fn().mockResolvedValue(undefined);
const mockTrackPlayerSkip = jest.fn().mockResolvedValue(undefined);
const mockTrackPlayerSeekTo = jest.fn().mockResolvedValue(undefined);
const mockPlay = jest.fn().mockResolvedValue(undefined);
const mockPause = jest.fn().mockResolvedValue(undefined);
const mockSeekBy = jest.fn().mockResolvedValue(undefined);

jest.mock("react-native-track-player", () => ({
  __esModule: true,
  default: {
    setQueue: (...args: unknown[]) => mockSetQueue(...args),
    skip: (...args: unknown[]) => mockTrackPlayerSkip(...args),
    seekTo: (...args: unknown[]) => mockTrackPlayerSeekTo(...args),
    play: (...args: unknown[]) => mockPlay(...args),
    pause: (...args: unknown[]) => mockPause(...args),
    seekBy: (...args: unknown[]) => mockSeekBy(...args),
  },
  State: { None: "none", Playing: "playing", Paused: "paused" },
  useActiveTrack: () => undefined,
  usePlaybackState: () => ({ state: "paused" }),
  useProgress: () => ({ position: 0, duration: 0, buffered: 0 }),
}));

const capsule: Capsule = {
  id: "capsule-1",
  title: "The Architecture of Victoria Terminus",
  topic: "Urban History",
  language: "en-IN",
  targetSeconds: 60,
  audioSeconds: 60,
  transcript: "Some transcript text.",
  segments: [
    { index: 0, url: "https://cdn.example.com/segment-0.mp3", durationSeconds: 30 },
    { index: 1, url: "https://cdn.example.com/segment-1.mp3", durationSeconds: 30 },
  ],
  createdAt: "2026-08-14T00:00:00.000Z",
};

describe("CapsulePlayer", () => {
  beforeEach(() => {
    mockSetQueue.mockClear();
    mockTrackPlayerSkip.mockClear();
    mockTrackPlayerSeekTo.mockClear();
    mockPlay.mockClear();
    mockPause.mockClear();
    mockSeekBy.mockClear();
    useCapsuleStore.setState({ capsules: [] });
  });

  it("starts from persisted progress", async () => {
    render(<CapsulePlayer capsule={capsule} initialPositionSeconds={42} onProgress={jest.fn()} />);
    const { index, offsetSeconds } = segmentAt(capsule.segments, 42);
    await waitFor(() => {
      expect(mockTrackPlayerSkip).toHaveBeenCalledWith(index);
      expect(mockTrackPlayerSeekTo).toHaveBeenCalledWith(offsetSeconds);
    });
  });

  it("queues segments in index order, using downloaded local URIs once every segment is present", async () => {
    useCapsuleStore.setState({
      capsules: [
        {
          ...capsule,
          progressSeconds: 0,
          saved: false,
          downloadedSegmentUris: { 0: "file:///a/segment-0.mp3", 1: "file:///a/segment-1.mp3" },
        },
      ],
    });

    render(<CapsulePlayer capsule={capsule} initialPositionSeconds={0} onProgress={jest.fn()} />);

    await waitFor(() => expect(mockSetQueue).toHaveBeenCalled());
    const queued = mockSetQueue.mock.calls[0][0];
    expect(queued.map((track: { url: string }) => track.url)).toEqual([
      "file:///a/segment-0.mp3",
      "file:///a/segment-1.mp3",
    ]);
  });

  it("does not show a playback-speed or regenerate control", async () => {
    render(<CapsulePlayer capsule={capsule} initialPositionSeconds={0} onProgress={jest.fn()} />);
    await waitFor(() => expect(mockSetQueue).toHaveBeenCalled());
    expect(screen.queryByText(/speed/i)).toBeNull();
    expect(screen.queryByText(/regenerate/i)).toBeNull();
  });

  it("toggles play/pause via TrackPlayer", async () => {
    render(<CapsulePlayer capsule={capsule} initialPositionSeconds={0} onProgress={jest.fn()} />);
    await waitFor(() => expect(mockSetQueue).toHaveBeenCalled());

    await userEvent.setup().press(screen.getByRole("button", { name: "Play" }));
    expect(mockPlay).toHaveBeenCalled();
  });
});
