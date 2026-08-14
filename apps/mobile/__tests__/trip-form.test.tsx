import React from "react";
import { render, screen, userEvent } from "@testing-library/react-native";
import { TripForm } from "../src/features/trip/trip-form";

describe("TripForm", () => {
  it("requires both endpoints before moving to transport selection", async () => {
    const onContinue = jest.fn();
    const user = userEvent.setup();
    await render(<TripForm onContinue={onContinue} />);

    await user.type(screen.getByLabelText("Start"), "Rajiv Chowk");
    await user.press(screen.getByRole("button", { name: "Continue" }));

    expect(onContinue).not.toHaveBeenCalled();
    expect(screen.getByText("Enter a destination")).toBeVisible();
  });
});
