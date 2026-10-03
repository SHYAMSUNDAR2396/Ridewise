import React from "react";
import { render, screen } from "@testing-library/react-native";
import App from "../App";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest"),
);

test("renders the tab shell on Listen Now", async () => {
  await render(<App />);
  expect((await screen.findAllByText("Listen Now")).length).toBeGreaterThan(0);
  expect(screen.getByRole("tab", { name: "Plan" })).toBeTruthy();
  expect(screen.getByRole("tab", { name: "Library" })).toBeTruthy();
});
