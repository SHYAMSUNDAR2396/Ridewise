import React from "react";
import { render, screen, userEvent } from "@testing-library/react-native";
import { HomeScreen } from "../src/screens/HomeScreen";
import { useCapsuleStore } from "../src/features/capsules/capsule-store";
import { useTripStore } from "../src/features/trip/trip-store";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest"),
);

const mockNavigate = jest.fn();
jest.mock("@react-navigation/native", () => {
  const actual = jest.requireActual("@react-navigation/native");
  return { ...actual, useNavigation: () => ({ navigate: mockNavigate }) };
});

const capsule = {
  id: "capsule-1",
  title: "Index Funds, Explained",
  topic: "Personal finance",
  language: "en-IN" as const,
  targetSeconds: 2100,
  audioSeconds: 2100,
  transcript: "Transcript.",
  segments: [{ index: 0, url: "https://cdn.example.com/0.mp3", durationSeconds: 2100 }],
  createdAt: "2026-10-03T00:00:00.000Z",
};

describe("HomeScreen (Listen Now)", () => {
  beforeEach(() => {
    mockNavigate.mockReset();
    useCapsuleStore.setState({ capsules: [] });
    useTripStore.setState({ draft: {} });
  });

  it("starts planning from the hero card", async () => {
    await render(<HomeScreen />);
    await userEvent.setup().press(screen.getByRole("button", { name: "Plan a capsule" }));
    expect(mockNavigate).toHaveBeenCalledWith("Plan");
  });

  it("shows an empty state until a capsule exists", async () => {
    await render(<HomeScreen />);
    expect(screen.getByText("No capsules yet")).toBeVisible();
  });

  it("shows the planned trip on the hero card", async () => {
    useTripStore.setState({
      draft: { startLabel: "Andheri", endLabel: "Churchgate", transportMode: "local_train" },
    });
    await render(<HomeScreen />);
    expect(screen.getByText("Andheri to Churchgate")).toBeVisible();
    expect(screen.getByText("Local train")).toBeVisible();
  });

  it("opens a recent capsule in the player and offers to continue a started one", async () => {
    useCapsuleStore.setState({
      capsules: [{ ...capsule, saved: false, progressSeconds: 600, downloadedSegmentUris: {} }],
    });
    await render(<HomeScreen />);

    await userEvent.setup().press(screen.getByRole("button", { name: "Continue Index Funds, Explained" }));
    expect(mockNavigate).toHaveBeenCalledWith("Player", {
      capsule: expect.objectContaining({ id: "capsule-1" }),
    });
  });
});
