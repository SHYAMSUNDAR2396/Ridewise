import { useTripStore } from "../src/features/trip/trip-store";

describe("useTripStore", () => {
  beforeEach(() => {
    useTripStore.setState({ draft: {} });
  });

  it("clears a stale manualSeconds when setEndpoints is called for a different route", () => {
    useTripStore.getState().setManualSeconds(2700);
    expect(useTripStore.getState().draft.manualSeconds).toBe(2700);

    useTripStore.getState().setEndpoints("Rajiv Chowk", "Hauz Khas");

    expect(useTripStore.getState().draft.manualSeconds).toBeUndefined();
    expect("manualSeconds" in useTripStore.getState().draft).toBe(false);
  });

  it("clears a stale manualSeconds when setTransportMode is called", () => {
    useTripStore.getState().setManualSeconds(2700);
    expect(useTripStore.getState().draft.manualSeconds).toBe(2700);

    useTripStore.getState().setTransportMode("walk");

    expect(useTripStore.getState().draft.manualSeconds).toBeUndefined();
    expect("manualSeconds" in useTripStore.getState().draft).toBe(false);
  });
});
