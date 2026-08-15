import React from "react";
import { render, screen, userEvent, waitFor } from "@testing-library/react-native";
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import type { Capsule } from "@commute-capsule/domain";
import { LibraryScreen } from "../src/screens/LibraryScreen";
import { useCapsuleStore, type StoredCapsule } from "../src/features/capsules/capsule-store";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest"),
);

const mockNavigate = jest.fn();
jest.mock("@react-navigation/native", () => {
  const actual = jest.requireActual("@react-navigation/native");
  return {
    ...actual,
    useNavigation: () => ({ navigate: mockNavigate }),
  };
});

const capsule: Capsule = {
  id: "capsule-1",
  title: "The History of Colaba",
  topic: "Heritage Walk",
  language: "en-IN",
  targetSeconds: 2700,
  audioSeconds: 2700,
  transcript: "Transcript text.",
  segments: [
    { index: 0, url: "https://cdn.example.com/segment-0.mp3", durationSeconds: 1350 },
    { index: 1, url: "https://cdn.example.com/segment-1.mp3", durationSeconds: 1350 },
  ],
  createdAt: "2026-08-14T00:00:00.000Z",
};

describe("LibraryScreen", () => {
  beforeEach(() => {
    mockNavigate.mockReset();
    useCapsuleStore.setState({ capsules: [] });
  });

  it("shows a saved capsule under the Saved tab", async () => {
    useCapsuleStore.setState({
      capsules: [{ ...capsule, saved: true, progressSeconds: 20, downloadedSegmentUris: {} }],
    });
    await render(<LibraryScreen />);
    await userEvent.setup().press(screen.getByRole("tab", { name: "Saved" }));
    expect(screen.getByText(capsule.title)).toBeVisible();
  });

  it("shows all capsules under the Recent tab by default", async () => {
    useCapsuleStore.setState({
      capsules: [{ ...capsule, saved: false, progressSeconds: 0, downloadedSegmentUris: {} }],
    });
    await render(<LibraryScreen />);
    expect(screen.getByText(capsule.title)).toBeVisible();
  });

  it("hides a not-yet-saved capsule from the Saved tab", async () => {
    useCapsuleStore.setState({
      capsules: [{ ...capsule, saved: false, progressSeconds: 0, downloadedSegmentUris: {} }],
    });
    await render(<LibraryScreen />);
    await userEvent.setup().press(screen.getByRole("tab", { name: "Saved" }));
    expect(screen.queryByText(capsule.title)).toBeNull();
  });

  it("shows the offline indicator only when every segment is downloaded", async () => {
    useCapsuleStore.setState({
      capsules: [
        {
          ...capsule,
          saved: false,
          progressSeconds: 0,
          downloadedSegmentUris: { 0: "file:///a/segment-0.mp3" },
        },
      ],
    });
    await render(<LibraryScreen />);
    await waitFor(() => expect(screen.getByText(capsule.title)).toBeVisible());
    expect(screen.queryByLabelText("Downloaded offline")).toBeNull();
  });

  it("shows the offline indicator and lists under Downloaded once every segment is present", async () => {
    useCapsuleStore.setState({
      capsules: [
        {
          ...capsule,
          saved: false,
          progressSeconds: 0,
          downloadedSegmentUris: {
            0: "file:///a/segment-0.mp3",
            1: "file:///a/segment-1.mp3",
          },
        },
      ],
    });
    await render(<LibraryScreen />);
    expect(screen.getByLabelText("Downloaded offline")).toBeTruthy();

    await userEvent.setup().press(screen.getByRole("tab", { name: "Downloaded" }));
    expect(screen.getByText(capsule.title)).toBeVisible();
  });

  it("navigates to the Player screen when a row is pressed", async () => {
    useCapsuleStore.setState({
      capsules: [{ ...capsule, saved: false, progressSeconds: 0, downloadedSegmentUris: {} }],
    });
    await render(<LibraryScreen />);
    await userEvent.setup().press(screen.getByText(capsule.title));
    expect(mockNavigate).toHaveBeenCalledWith(
      "Player",
      expect.objectContaining({ capsule: expect.objectContaining({ id: capsule.id }) }),
    );
  });

  it("survives a simulated app restart: progress, saved, and downloaded state rehydrate from AsyncStorage", async () => {
    useCapsuleStore.setState({
      capsules: [
        {
          ...capsule,
          saved: true,
          progressSeconds: 900,
          downloadedSegmentUris: { 0: "file:///a/segment-0.mp3", 1: "file:///a/segment-1.mp3" },
        },
      ],
    });

    // Wait for the persist middleware's async write to land in AsyncStorage.
    const AsyncStorage = require("@react-native-async-storage/async-storage").default;
    await waitFor(async () => {
      const raw = await AsyncStorage.getItem("capsule-library");
      expect(raw).toContain(capsule.id);
    });

    // Simulate an app restart: a brand-new store instance (a fresh process
    // would create one from scratch) reading the same on-disk AsyncStorage
    // data useCapsuleStore just wrote, under the same persist key. Using a
    // second instance -- rather than clearing and rehydrating the original
    // -- avoids the original's own persist subscriber re-writing (and
    // clobbering) storage the moment its in-memory state is reset.
    const freshStoreOnRestart = create<{ capsules: StoredCapsule[] }>()(
      persist(() => ({ capsules: [] as StoredCapsule[] }), {
        name: "capsule-library",
        storage: createJSONStorage(() => AsyncStorage),
      }),
    );
    await freshStoreOnRestart.persist.rehydrate();

    const restored = freshStoreOnRestart.getState().capsules[0];
    expect(restored?.saved).toBe(true);
    expect(restored?.progressSeconds).toBe(900);
    expect(restored?.downloadedSegmentUris).toEqual({
      0: "file:///a/segment-0.mp3",
      1: "file:///a/segment-1.mp3",
    });
  });
});
