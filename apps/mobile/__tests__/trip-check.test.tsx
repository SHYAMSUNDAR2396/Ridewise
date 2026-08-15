import React from "react";
import { render, screen, userEvent, waitFor } from "@testing-library/react-native";
import { TripCheckScreen } from "../src/screens/TripCheckScreen";
import { useTripStore } from "../src/features/trip/trip-store";

const mockNavigate = jest.fn();

jest.mock("@react-navigation/native", () => {
  const actual = jest.requireActual("@react-navigation/native");
  return {
    ...actual,
    useNavigation: () => ({ navigate: mockNavigate }),
  };
});

const mockEstimateTrip = jest.fn();

jest.mock("../src/api/client", () => ({
  apiClient: {
    estimateTrip: (...args: unknown[]) => mockEstimateTrip(...args),
    createCapsule: jest.fn(),
  },
}));

describe("TripCheckScreen", () => {
  beforeEach(() => {
    mockNavigate.mockReset();
    mockEstimateTrip.mockReset();
    useTripStore.setState({ draft: { startLabel: "Rajiv Chowk", endLabel: "Hauz Khas", transportMode: "metro" } });
  });

  it("continues with an edited time when route estimation fails", async () => {
    mockEstimateTrip.mockRejectedValueOnce(new Error("network unavailable"));
    render(<TripCheckScreen />);

    await waitFor(() =>
      expect(screen.getByText("Couldn't estimate this route.")).toBeVisible(),
    );

    await userEvent.setup().clear(screen.getByLabelText("Estimated Travel Time"));
    await userEvent.setup().type(screen.getByLabelText("Estimated Travel Time"), "15");
    await userEvent.setup().press(screen.getByRole("button", { name: "Continue" }));

    expect(mockNavigate).toHaveBeenCalledWith("Topic");
  });

  it("retains start, destination, and transport mode after a failed estimate", async () => {
    mockEstimateTrip.mockRejectedValueOnce(new Error("network unavailable"));
    render(<TripCheckScreen />);

    await waitFor(() =>
      expect(screen.getByText("Couldn't estimate this route.")).toBeVisible(),
    );

    const draft = useTripStore.getState().draft;
    expect(draft.startLabel).toBe("Rajiv Chowk");
    expect(draft.endLabel).toBe("Hauz Khas");
    expect(draft.transportMode).toBe("metro");
  });

  it("commits an edited duration when Continue is tapped instead of Use manual time", async () => {
    mockEstimateTrip.mockResolvedValueOnce({
      durationSeconds: 1080,
      summary: "via Blue Line",
      source: "routing",
    });
    render(<TripCheckScreen />);

    await waitFor(() => expect(screen.getByText("18")).toBeVisible());

    await userEvent.setup().press(screen.getByLabelText("Edit duration"));
    await userEvent.setup().press(screen.getByLabelText("Increase minutes"));
    await userEvent.setup().press(screen.getByRole("button", { name: "Continue" }));

    expect(mockNavigate).toHaveBeenCalledWith("Topic");
    expect(useTripStore.getState().draft.manualSeconds).toBe(19 * 60);
  });

  it("shows the route summary and duration when estimation succeeds", async () => {
    mockEstimateTrip.mockResolvedValueOnce({
      durationSeconds: 1080,
      summary: "via Blue Line",
      source: "routing",
    });
    render(<TripCheckScreen />);

    await waitFor(() => expect(screen.getByText("18")).toBeVisible());
    expect(screen.getByText("Estimated Duration")).toBeVisible();
    expect(screen.getByText("Rajiv Chowk")).toBeVisible();
    expect(screen.getByText("Hauz Khas")).toBeVisible();
  });
});
