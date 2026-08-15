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

let mockPlaybackState: { state: string } = { state: "paused" };
let mockProgress: { position: number; duration: number; buffered: number } = {
  position: 0,
  duration: 0,
  buffered: 0,
};

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
  State: { None: "none", Playing: "playing", Paused: "paused", Error: "error" },
  useActiveTrack: () => undefined,
  usePlaybackState: () => mockPlaybackState,
  useProgress: () => mockProgress,
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
    mockPlaybackState = { state: "paused" };
    mockProgress = { position: 0, duration: 0, buffered: 0 };
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

  it("flushes the latest known progress on unmount", async () => {
    const onProgress = jest.fn();
    const { rerender, unmount } = await render(
      <CapsulePlayer capsule={capsule} initialPositionSeconds={0} onProgress={onProgress} />,
    );
    await waitFor(() => expect(mockSetQueue).toHaveBeenCalled());

    // Advance real playback progress so the flush has genuine, nonzero
    // elapsed time to report -- a flush of 0 is intentionally skipped
    // (see the "real initial resume position" test below), so this test
    // needs the mocked progress to move for the assertion to mean anything.
    mockProgress = { position: 30, duration: 100, buffered: 30 };
    await rerender(
      <CapsulePlayer capsule={capsule} initialPositionSeconds={0} onProgress={onProgress} />,
    );
    onProgress.mockClear();

    await unmount();

    expect(onProgress).toHaveBeenCalledTimes(1);
    expect(onProgress).toHaveBeenCalledWith(30);
  });

  it("flushes the real initial resume position, not 0, when unmounted before the first progress poll", async () => {
    const onProgress = jest.fn();
    const { unmount } = await render(
      <CapsulePlayer capsule={capsule} initialPositionSeconds={42} onProgress={onProgress} />,
    );

    // Unmount immediately -- before the async setQueue/skip/seekTo setup
    // resolves and before useProgress(1000) has reported anything but 0.
    await unmount();

    expect(onProgress).toHaveBeenCalledTimes(1);
    expect(onProgress).toHaveBeenCalledWith(42);
  });

  it("reports a playback error so the screen can offer retry (AUDIO_UNAVAILABLE)", async () => {
    mockPlaybackState = { state: "error" };
    const onPlaybackError = jest.fn();
    render(
      <CapsulePlayer
        capsule={capsule}
        initialPositionSeconds={0}
        onProgress={jest.fn()}
        onPlaybackError={onPlaybackError}
      />,
    );
    await waitFor(() => expect(onPlaybackError).toHaveBeenCalled());
  });
});
