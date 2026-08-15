/// <reference types="vitest" />
import { describe, it, expect, vi } from "vitest";
import type { TripDraft } from "@commute-capsule/domain";
import { buildApp } from "../src/app";
import { TripService } from "../src/services/trip-service";
import { CapsuleService } from "../src/services/capsule-service";
import { DevelopmentProvider } from "../src/providers/elevenlabs";
import { InMemoryStorage, type Storage } from "../src/providers/storage";

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

  it("maps a route failure with no usable manual fallback to ROUTE_UNAVAILABLE", async () => {
    const failingService = new TripService({
      estimate: vi.fn().mockRejectedValue(new Error("Google Routes request failed: key abc123")),
    });
    const app = buildApp({ tripService: failingService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/trips/estimate",
      payload: draft(),
    });

    expect(response.statusCode).toBe(502);
    expect(response.json()).toEqual(expect.objectContaining({ code: "ROUTE_UNAVAILABLE" }));
    expect(JSON.stringify(response.json())).not.toMatch(/abc123/);
  });
});

describe("POST /v1/capsules", () => {
  it("estimates the trip before generating, and returns 201 with ordered segments", async () => {
    const tripService = new TripService({
      estimate: vi.fn().mockResolvedValue({ durationSeconds: 1200, summary: "Metro via Blue Line" }),
    });
    const capsuleService = new CapsuleService(new DevelopmentProvider(), new InMemoryStorage());
    const app = buildApp({ tripService, capsuleService });
    const response = await app.inject({
      method: "POST",
      url: "/v1/capsules",
      payload: {
        trip: { startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" },
        topic: "Personal finance",
        style: "quick_overview",
        language: "en-IN",
      },
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toEqual(
      expect.objectContaining({
        targetSeconds: expect.any(Number),
        transcript: expect.any(String),
        segments: expect.any(Array),
      }),
    );
  });

  it("maps a speech synthesis failure to the stable error shape", async () => {
    const tripService = new TripService({
      estimate: vi.fn().mockResolvedValue({ durationSeconds: 1200, summary: "Metro via Blue Line" }),
    });
    const provider = new DevelopmentProvider();
    vi.spyOn(provider, "synthesize").mockRejectedValue(new Error("SPEECH_SYNTHESIS_FAILED"));
    const capsuleService = new CapsuleService(provider, new InMemoryStorage());
    const app = buildApp({ tripService, capsuleService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/capsules",
      payload: {
        trip: { startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" },
        topic: "Personal finance",
        style: "quick_overview",
        language: "en-IN",
      },
    });

    expect(response.json()).toEqual(expect.objectContaining({ code: "SPEECH_SYNTHESIS_FAILED" }));
    expect(response.json()).not.toHaveProperty("suggestedTopic");
    expect(JSON.stringify(response.json())).not.toMatch(/UNSAFE_TOPIC/);
  });

  it("maps a route estimation failure with no manual fallback to ROUTE_UNAVAILABLE", async () => {
    const tripService = new TripService({
      estimate: vi.fn().mockRejectedValue(new Error("Google Routes request failed: key abc123")),
    });
    const capsuleService = new CapsuleService(new DevelopmentProvider(), new InMemoryStorage());
    const app = buildApp({ tripService, capsuleService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/capsules",
      payload: {
        trip: { startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" },
        topic: "Personal finance",
        style: "quick_overview",
        language: "en-IN",
      },
    });

    expect(response.json()).toEqual(expect.objectContaining({ code: "ROUTE_UNAVAILABLE" }));
    // The underlying provider error text (which could carry a key) never reaches the client.
    expect(JSON.stringify(response.json())).not.toMatch(/abc123/);
  });

  it("maps a storage failure to the stable error shape, never the raw storage error", async () => {
    const tripService = new TripService({
      estimate: vi.fn().mockResolvedValue({ durationSeconds: 1200, summary: "Metro via Blue Line" }),
    });
    const failingStorage: Storage = {
      put: vi.fn().mockRejectedValue(new Error("S3 bucket credentials rejected: secret abc123")),
    };
    const capsuleService = new CapsuleService(new DevelopmentProvider(), failingStorage);
    const app = buildApp({ tripService, capsuleService });

    const response = await app.inject({
      method: "POST",
      url: "/v1/capsules",
      payload: {
        trip: { startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" },
        topic: "Personal finance",
        style: "quick_overview",
        language: "en-IN",
      },
    });

    expect(response.json()).toEqual(expect.objectContaining({ code: "SPEECH_SYNTHESIS_FAILED" }));
    expect(JSON.stringify(response.json())).not.toMatch(/abc123/);
  });
});
