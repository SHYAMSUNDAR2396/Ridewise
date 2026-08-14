/// <reference types="vitest" />
import { describe, it, expect, vi } from "vitest";
import type { TripDraft } from "@commute-capsule/domain";
import { buildApp } from "../src/app";
import { TripService } from "../src/services/trip-service";

function draft(overrides: Partial<TripDraft> = {}): TripDraft {
  return {
    startLabel: "Andheri",
    endLabel: "Bandra",
    transportMode: "metro",
    ...overrides,
  };
}

describe("POST /v1/trips/estimate", () => {
  it("returns a routing estimate when the provider succeeds", async () => {
    const tripService = new TripService({
      estimate: vi.fn().mockResolvedValue({ durationSeconds: 1200, summary: "Metro via Blue Line" }),
    });
    const app = buildApp({ tripService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/trips/estimate",
      payload: draft(),
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      durationSeconds: 1200,
      summary: "Metro via Blue Line",
      source: "routing",
    });
  });

  it("returns a manual estimate when routing is unavailable", async () => {
    const failingService = new TripService({ estimate: vi.fn().mockRejectedValue(new Error("unavailable")) });
    const app = buildApp({ tripService: failingService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/trips/estimate",
      payload: { ...draft(), manualSeconds: 900 },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ durationSeconds: 900, source: "manual" });
  });

  it("returns 400 for an invalid request body", async () => {
    const tripService = new TripService({ estimate: vi.fn() });
    const app = buildApp({ tripService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/trips/estimate",
      payload: { startLabel: "Andheri" },
    });

    expect(response.statusCode).toBe(400);
  });
});
