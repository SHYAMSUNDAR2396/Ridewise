import React from "react";
import { render, screen, userEvent } from "@testing-library/react-native";
import { HomeScreen } from "../src/screens/HomeScreen";

const mockNavigate = jest.fn();

describe("HomeScreen", () => {
  beforeEach(() => {
    mockNavigate.mockReset();
  });

  it("navigates to the Library screen from the header link", async () => {
    await render(
      <HomeScreen
        navigation={{ navigate: mockNavigate } as never}
        route={{ key: "Home", name: "Home" } as never}
      />,
    );

    await userEvent.setup().press(screen.getByRole("button", { name: "Open Library" }));
    expect(mockNavigate).toHaveBeenCalledWith("Library");
  });
});
