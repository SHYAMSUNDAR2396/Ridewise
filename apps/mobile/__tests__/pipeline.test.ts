import type { CreateCapsuleRequest } from "@commute-capsule/domain";
import { createCapsuleOnDevice, type PipelineDeps } from "../src/features/generation/pipeline";
import { GenerationError } from "../src/features/generation/types";

const request = (seconds?: number): CreateCapsuleRequest => ({
  trip: { startLabel: "A", endLabel: "B", transportMode: "metro", manualSeconds: seconds },
  topic: "Careers",
  style: "quick_overview",
  language: "en-IN",
});

function makeDeps(overrides: Partial<PipelineDeps> & { secondsPerSegment?: number; sentences?: number } = {}) {
  const spoken: string[] = [];
  const cleaned: string[] = [];
  const written: number[] = [];
  const deps: PipelineDeps = {
    script: {
      async write({ targetWords }) {
        written.push(targetWords);
        const sentences = overrides.sentences ?? 12;
        return { title: "A title", transcript: Array.from({ length: sentences }, (_, i) => `Sentence number ${i + 1} is here.`).join(" ") };
      },
    },
    speech: {
      async synthesizeToFile(text) {
        spoken.push(text);
        return { durationSeconds: overrides.secondsPerSegment ?? 10 };
      },
    },
    segmentPath: (id, index) => `/docs/${id}/${index}.wav`,
    newId: () => "cap-1",
    now: () => new Date("2026-10-03T00:00:00.000Z"),
    cleanup: async (id) => {
      cleaned.push(id);
    },
    ...overrides,
  };
  return { deps, spoken, cleaned, written };
}

describe("createCapsuleOnDevice", () => {
  it("builds a capsule of local segments that fits the trip", async () => {
    const { deps, written } = makeDeps({ secondsPerSegment: 10 });
    const capsule = await createCapsuleOnDevice(request(1200), deps);

    expect(capsule.targetSeconds).toBe(1080);
    expect(capsule.segments.length).toBeGreaterThan(0);
    expect(capsule.segments[0].url).toBe("file:///docs/cap-1/0.wav");
    expect(capsule.audioSeconds).toBe(capsule.segments.length * 10);
    expect(capsule.audioSeconds).toBeLessThanOrEqual(capsule.targetSeconds);
    expect(capsule.language).toBe("en-IN");
    expect(written).toEqual([2700]);
  });

  it("makes one shorter attempt after an overrun, stopping early and cleaning up", async () => {
    // The first segment alone is longer than the 1080 s target, so speaking stops there.
    const { deps, spoken, cleaned, written } = makeDeps({ secondsPerSegment: 1100 });
    await expect(createCapsuleOnDevice(request(1200), deps)).rejects.toMatchObject({
      code: "CAPSULE_TOO_LONG",
    });

    expect(written).toEqual([2700, 2295]);
    expect(cleaned).toEqual(["cap-1", "cap-1"]);
    expect(spoken).toHaveLength(2); // one segment per attempt, then stopped
  });

  it("succeeds on the shorter second attempt", async () => {
    let calls = 0;
    const { deps } = makeDeps();
    deps.script = {
      async write() {
        calls += 1;
        return { title: "T", transcript: calls === 1 ? "A long sentence. ".repeat(60) : "Short one." };
      },
    };
    deps.speech = {
      async synthesizeToFile(text) {
        return { durationSeconds: text.length > 20 ? 600 : 5 };
      },
    };

    const capsule = await createCapsuleOnDevice(request(1200), deps);
    expect(calls).toBe(2);
    expect(capsule.audioSeconds).toBe(5);
  });

  it("maps a script failure to SCRIPT_GENERATION_FAILED", async () => {
    const { deps } = makeDeps();
    deps.script = { write: () => Promise.reject(new Error("model crashed")) };
    await expect(createCapsuleOnDevice(request(1200), deps)).rejects.toMatchObject({
      code: "SCRIPT_GENERATION_FAILED",
    });
  });

  it("retries a failed segment, then gives up with SPEECH_SYNTHESIS_FAILED and cleans up", async () => {
    const { deps, cleaned } = makeDeps();
    let attempts = 0;
    deps.speech = {
      async synthesizeToFile() {
        attempts += 1;
        throw new Error("engine error");
      },
    };
    await expect(createCapsuleOnDevice(request(1200), deps)).rejects.toMatchObject({
      code: "SPEECH_SYNTHESIS_FAILED",
    });
    expect(attempts).toBe(3);
    expect(cleaned).toEqual(["cap-1"]);
  });

  it("requires a trip time", async () => {
    const { deps } = makeDeps();
    await expect(createCapsuleOnDevice(request(), deps)).rejects.toBeInstanceOf(GenerationError);
    await expect(createCapsuleOnDevice(request(), deps)).rejects.toMatchObject({ code: "ROUTE_UNAVAILABLE" });
  });
});
