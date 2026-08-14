import React from "react";
import { render, screen, userEvent, waitFor } from "@testing-library/react-native";
import { TopicScreen } from "../src/screens/TopicScreen";
import { useTripStore } from "../src/features/trip/trip-store";

const mockNavigate = jest.fn();

jest.mock("@react-navigation/native", () => {
  const actual = jest.requireActual("@react-navigation/native");
  return {
    ...actual,
    useNavigation: () => ({ navigate: mockNavigate }),
  };
});

const mockCreateCapsule = jest.fn();

jest.mock("../src/api/client", () => ({
  apiClient: {
    estimateTrip: jest.fn(),
    createCapsule: (...args: unknown[]) => mockCreateCapsule(...args),
  },
}));

describe("TopicScreen", () => {
  beforeEach(() => {
    mockNavigate.mockReset();
    mockCreateCapsule.mockReset();
    useTripStore.setState({
      draft: {
        startLabel: "Rajiv Chowk",
        endLabel: "Hauz Khas",
        transportMode: "metro",
        estimatedSeconds: 1080,
      },
    });
  });

  it("disables Generate until a topic is chosen", async () => {
    await render(<TopicScreen />);
    expect(screen.getByRole("button", { name: "Generate my capsule" }).props.accessibilityState.disabled).toBe(true);

    await userEvent.setup().press(screen.getByRole("button", { name: "Careers" }));
    expect(screen.getByRole("button", { name: "Generate my capsule" }).props.accessibilityState.disabled).toBe(false);
  });

  it("keeps selections and offers Retry when generation fails", async () => {
    mockCreateCapsule.mockRejectedValueOnce(new Error("boom"));
    await render(<TopicScreen />);

    await userEvent.setup().press(screen.getByRole("button", { name: "Careers" }));
    await userEvent.setup().press(screen.getByRole("button", { name: "Generate my capsule" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "Retry" })).toBeVisible());
    expect(mockNavigate).not.toHaveBeenCalled();
    // selection survived the failure
    expect(screen.getByRole("button", { name: "Generate my capsule" }).props.accessibilityState.disabled).toBe(false);
  });

  it("navigates to Player with the capsule on success", async () => {
    const capsule = { id: "c1" };
    mockCreateCapsule.mockResolvedValueOnce(capsule);
    await render(<TopicScreen />);

    await userEvent.setup().press(screen.getByRole("button", { name: "Careers" }));
    await userEvent.setup().press(screen.getByRole("button", { name: "Generate my capsule" }));

    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith("Player", { capsule }));
    expect(mockCreateCapsule).toHaveBeenCalledWith(
      expect.objectContaining({ topic: "Careers", style: "quick_overview", language: "en-IN" }),
    );
  });
});
