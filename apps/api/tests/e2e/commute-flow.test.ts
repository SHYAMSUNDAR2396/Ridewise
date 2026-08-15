/// <reference types="vitest" />
import { describe, it, expect } from "vitest";
import { buildApp } from "../../src/app";

describe("end-to-end: full capsule creation flow", () => {
  it("creates an English metro capsule from a route estimate", async () => {
    const app = buildApp({ providerMode: "development" });
    const response = await app.inject({
      method: "POST",
      url: "/v1/capsules",
      payload: {
        trip: { startLabel: "Rajiv Chowk", endLabel: "Noida Sector 18", transportMode: "metro" },
        topic: "Technology",
        style: "quick_overview",
        language: "en-IN",
      },
    });

    expect(response.statusCode).toBe(201);
    const capsule = response.json();
    expect(capsule.audioSeconds).toBeLessThanOrEqual(capsule.targetSeconds);
    expect(capsule.segments.length).toBeGreaterThanOrEqual(1);
    expect(capsule.segments.map((s: { index: number }) => s.index)).toEqual(
      capsule.segments.map((_: unknown, i: number) => i),
    );

    const body = JSON.stringify(capsule);
    expect(body).not.toMatch(/voiceId/i);
    expect(body).not.toMatch(/xi-api-key/i);
    expect(body).not.toMatch(/elevenlabs\.io/i);
  });

  it("estimates a trip standalone via /v1/trips/estimate in development mode", async () => {
    const app = buildApp({ providerMode: "development" });
    const response = await app.inject({
      method: "POST",
      url: "/v1/trips/estimate",
      payload: {
        startLabel: "Rajiv Chowk",
        endLabel: "Noida Sector 18",
        transportMode: "metro",
      },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ source: "routing" });
  });
});
