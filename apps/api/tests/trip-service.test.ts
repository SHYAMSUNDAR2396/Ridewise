/// <reference types="vitest" />
import { describe, it, expect, vi } from "vitest";
import type { TripDraft } from "@commute-capsule/domain";
import { TripService } from "../src/services/trip-service";

function draft(overrides: Partial<TripDraft> = {}): TripDraft {
  return {
    startLabel: "Andheri",
    endLabel: "Bandra",
    transportMode: "metro",
    ...overrides,
  };
}

describe("TripService", () => {
  it("uses a routing estimate when the provider succeeds", async () => {
    const service = new TripService({
      estimate: vi.fn().mockResolvedValue({ durationSeconds: 1200, summary: "Metro via Blue Line" }),
    });
    await expect(service.estimate(draft())).resolves.toEqual({
      durationSeconds: 1200,
      summary: "Metro via Blue Line",
      source: "routing",
    });
  });

  it("uses manual time after a provider failure", async () => {
    const service = new TripService({ estimate: vi.fn().mockRejectedValue(new Error("unavailable")) });
    await expect(service.estimate({ ...draft(), manualSeconds: 900 })).resolves.toEqual({
      durationSeconds: 900,
      summary: "Manual duration",
      source: "manual",
    });
  });

  it("rethrows the provider error when no manual duration is available", async () => {
    const service = new TripService({ estimate: vi.fn().mockRejectedValue(new Error("unavailable")) });
    await expect(service.estimate(draft())).rejects.toThrow("unavailable");
  });

  it("rethrows the provider error when the manual duration is below the 60 second minimum", async () => {
    const service = new TripService({ estimate: vi.fn().mockRejectedValue(new Error("unavailable")) });
    await expect(service.estimate({ ...draft(), manualSeconds: 30 })).rejects.toThrow("unavailable");
  });
});
