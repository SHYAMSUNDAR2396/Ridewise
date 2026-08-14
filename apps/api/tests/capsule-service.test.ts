/// <reference types="vitest" />
import { describe, it, expect, vi } from "vitest";
import { CapsuleService } from "../src/services/capsule-service";
import { DevelopmentProvider } from "../src/providers/elevenlabs";
import { InMemoryStorage } from "../src/providers/storage";

const request = {
  trip: { startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" as const },
  topic: "Personal finance",
  style: "quick_overview" as const,
  language: "en-IN" as const,
};

describe("CapsuleService.create", () => {
  it("publishes a capsule within the target duration", async () => {
    const service = new CapsuleService(new DevelopmentProvider(), new InMemoryStorage());
    const capsule = await service.create(request, 900);

    expect(capsule.targetSeconds).toBe(810);
    expect(capsule.audioSeconds).toBeLessThanOrEqual(810);
    expect(capsule.transcript.length).toBeGreaterThan(0);
    expect(capsule.language).toBe("en-IN");
  });

  it("stores segments in index order", async () => {
    const service = new CapsuleService(new DevelopmentProvider(), new InMemoryStorage());
    const capsule = await service.create(request, 2400);

    expect(capsule.segments.length).toBeGreaterThan(0);
    expect(capsule.segments.map((s) => s.index)).toEqual(
      capsule.segments.map((_, i) => i),
    );
    expect(capsule.audioSeconds).toBeCloseTo(
      capsule.segments.reduce((sum, s) => sum + s.durationSeconds, 0),
      5,
    );
  });

  it("retries only the failed segment and keeps successful ones", async () => {
    const provider = new DevelopmentProvider();
    const synthesize = vi.spyOn(provider, "synthesize");
    let failed = false;
    synthesize.mockImplementation(async (text: string) => {
      if (!failed && text.length > 0) {
        failed = true;
        throw new Error("SPEECH_SYNTHESIS_FAILED");
      }
      const words = text.split(/\s+/).filter(Boolean).length;
      return { bytes: new Uint8Array(text.length), durationSeconds: (words / 150) * 60 };
    });

    const service = new CapsuleService(provider, new InMemoryStorage());
    const capsule = await service.create(request, 900);

    expect(capsule.segments.length).toBeGreaterThan(0);
    expect(synthesize).toHaveBeenCalledTimes(capsule.segments.length + 1);
  });

  it("returns CAPSULE_TOO_LONG after one failed shortening attempt", async () => {
    const provider = new DevelopmentProvider();
    vi.spyOn(provider, "synthesize").mockResolvedValue({
      bytes: new Uint8Array(1),
      durationSeconds: 10_000,
    });

    const service = new CapsuleService(provider, new InMemoryStorage());
    await expect(service.create(request, 900)).rejects.toThrow("CAPSULE_TOO_LONG");
  });
});
