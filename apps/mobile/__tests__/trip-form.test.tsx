import React from "react";
import { render, screen, userEvent } from "@testing-library/react-native";
import { TripForm } from "../src/features/trip/trip-form";

describe("TripForm", () => {
  it("requires both endpoints", async () => {
    const onContinue = jest.fn();
    const user = userEvent.setup();
    await render(<TripForm onContinue={onContinue} />);

    await user.type(screen.getByLabelText("Start"), "Rajiv Chowk");
    await user.press(screen.getByRole("button", { name: "Continue" }));

    expect(onContinue).not.toHaveBeenCalled();
    expect(screen.getByText("Enter a destination")).toBeVisible();
  });

  it("requires a transport mode", async () => {
    const onContinue = jest.fn();
    const user = userEvent.setup();
    await render(<TripForm onContinue={onContinue} />);

    await user.type(screen.getByLabelText("Start"), "Rajiv Chowk");
    await user.type(screen.getByLabelText("Destination"), "Hauz Khas");
    await user.press(screen.getByRole("button", { name: "Continue" }));

    expect(onContinue).not.toHaveBeenCalled();
    expect(screen.getByText("Choose how you are travelling")).toBeVisible();
  });

  it("passes endpoints and mode on when complete", async () => {
    const onContinue = jest.fn();
    const user = userEvent.setup();
    await render(<TripForm onContinue={onContinue} />);

    await user.type(screen.getByLabelText("Start"), "Rajiv Chowk");
    await user.type(screen.getByLabelText("Destination"), "Hauz Khas");
    await user.press(screen.getByRole("button", { name: "Metro" }));
    await user.press(screen.getByRole("button", { name: "Continue" }));

    expect(onContinue).toHaveBeenCalledWith("Rajiv Chowk", "Hauz Khas", "metro");
  });
});
