import React from "react";
import { render, screen, userEvent } from "@testing-library/react-native";
import { MiniPlayer } from "../src/components/MiniPlayer";
import { useCapsuleStore } from "../src/features/capsules/capsule-store";
import { useNowPlaying } from "../src/features/capsules/now-playing";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest"),
);

const stored = {
  id: "capsule-1",
  title: "Index Funds, Explained",
  topic: "Personal finance",
  language: "en-IN" as const,
  targetSeconds: 2100,
  audioSeconds: 2100,
  transcript: "Transcript.",
  segments: [{ index: 0, url: "https://cdn.example.com/0.mp3", durationSeconds: 2100 }],
  createdAt: "2026-10-03T00:00:00.000Z",
  saved: false,
  progressSeconds: 372,
  downloadedSegmentUris: {},
};

describe("MiniPlayer", () => {
  beforeEach(() => {
    useCapsuleStore.setState({ capsules: [stored] });
    useNowPlaying.setState({ capsuleId: null });
  });

  it("renders nothing until a capsule is playing", async () => {
    await render(<MiniPlayer onOpen={jest.fn()} />);
    expect(screen.queryByText("Index Funds, Explained")).toBeNull();
  });

  it("shows the playing capsule and time left, and opens the player", async () => {
    useNowPlaying.setState({ capsuleId: "capsule-1" });
    const onOpen = jest.fn();
    await render(<MiniPlayer onOpen={onOpen} />);

    expect(screen.getByText("Index Funds, Explained")).toBeVisible();
    expect(screen.getByText("28:48 left")).toBeVisible();

    await userEvent.setup().press(screen.getByRole("button", { name: "Open player, Index Funds, Explained" }));
    expect(onOpen).toHaveBeenCalledWith(expect.objectContaining({ id: "capsule-1" }));
  });
});
