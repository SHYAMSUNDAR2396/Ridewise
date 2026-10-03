import React from "react";
import { act, render, screen, userEvent, waitFor } from "@testing-library/react-native";
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

const mockGenerate = jest.fn();

jest.mock("../src/features/generation/native/runtime", () => ({
  generateCapsuleOnDevice: (...args: unknown[]) => mockGenerate(...args),
}));

describe("TopicScreen", () => {
  beforeEach(() => {
    mockNavigate.mockReset();
    mockGenerate.mockReset();
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
    mockGenerate.mockRejectedValueOnce(new Error("boom"));
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
    mockGenerate.mockResolvedValueOnce(capsule);
    await render(<TopicScreen />);

    await userEvent.setup().press(screen.getByRole("button", { name: "Careers" }));
    await userEvent.setup().press(screen.getByRole("button", { name: "Generate my capsule" }));

    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith("Player", { capsule }));
    expect(mockGenerate).toHaveBeenCalledWith(
      expect.objectContaining({ topic: "Careers", style: "quick_overview", language: "en-IN" }),
      expect.any(Function),
    );
  });

  it("shows what the phone is doing while it generates", async () => {
    let report: (progress: unknown) => void = () => undefined;
    let finish: (capsule: unknown) => void = () => undefined;
    mockGenerate.mockImplementationOnce(
      (_input: unknown, onProgress: (progress: unknown) => void) => {
        report = onProgress;
        return new Promise((resolve) => {
          finish = resolve;
        });
      },
    );
    await render(<TopicScreen />);

    await userEvent.setup().press(screen.getByRole("button", { name: "Careers" }));
    await userEvent.setup().press(screen.getByRole("button", { name: "Generate my capsule" }));

    await waitFor(() => expect(screen.getByText("Preparing your capsule...")).toBeVisible());
    await act(async () => report({ phase: "models", done: 42, total: 100 }));
    expect(screen.getByText("Getting ready, 42%")).toBeVisible();
    await act(async () => report({ phase: "voice", done: 2, total: 9 }));
    expect(screen.getByText("Recording part 3 of 9...")).toBeVisible();

    await act(async () => finish({ id: "c1" }));
  });
});
