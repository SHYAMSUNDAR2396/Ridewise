# Ridewise ElevenLabs MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reduced-scope Ridewise MVP — typed route entry, transport mode, duration estimate with manual override, topic and style selection, and an English solo audio capsule with transcript, player, and local library — on ElevenLabs.

**Architecture:** This plan is an **overlay on `docs/superpowers/plans/2026-07-31-commute-capsule-india.md`**, which already specifies exactly this product scope. That plan remains the spine: its Tasks 1-8, file structure, screens, stores, and tests are executed as written, except where this document overrides them. The overrides replace the OpenAI provider with ElevenLabs and replace single-file audio with ordered, independently retryable segments.

**Tech Stack:** TypeScript, npm workspaces, **bare React Native (community CLI — not Expo)**, React Navigation, `react-native-track-player`, AsyncStorage, `react-native-blob-util`, Zustand, React Query, Fastify, Zod, Vitest, Jest with the `react-native` preset, React Native Testing Library, Maestro, Google Maps Routes API, ElevenLabs Script Agent, ElevenLabs Text to Speech (`eleven_multilingual_v2`), S3-compatible object storage.

## How To Use This Plan

Execute the base plan task by task. Before starting each base task, check the Override Table below. Tasks A, B, and C in this document are **new** and slot into the base sequence at the stated points.

Execution order:

```
Base Task 1  (with Override 1)
Base Task 2  (unchanged)
Task A       (new — segmenter)
Task B       (new — ElevenLabs provider)
Base Task 3  (with Override 3)
Base Task 4  (with Override 4)
Base Task 5  (with Override 5)
Task C       (new — multi-segment playback)
Base Task 6  (with Override 6)
Base Task 7  (with Override 7)
Base Task 8  (with Override 8)
```

## Global Constraints

Inherited verbatim from the base plan, with the language and provider constraints amended:

- Build a mobile application focused on urban commuters in India without tying it to one city or transport network.
- **The MVP is English-only.** `language` is the literal `"en-IN"`. Hindi is out of scope for this plan.
- **The MVP is solo narration only.** The two-host conversation format in `specs/2026-08-13-ridewise-conversation-capsules-design.md` is out of scope for this plan.
- The user enters a start point, destination, and transport mode; a manual duration override must always be available.
- Supported transport choices are metro, bus, local train, cab/car, bike, walk, and other.
- Do not require location permission or an account to complete the core route-to-audio flow. **No current-location shortcut in this MVP** — typed entry only.
- Keep maps, AI, text-to-speech, and storage credentials on the server; never bundle them into the mobile application.
- Generate a transcript with every capsule, and retain listening progress, saved state, and downloaded state locally.
- Set `targetSeconds` to `max(60, tripSeconds - min(max(round(tripSeconds * 0.1), 60), 180))`; generated audio must not exceed `targetSeconds`.
- Route lookup, low connectivity, and generation failures must preserve enough user input for a manual-duration retry.
- Every text-to-speech segment must be 8,000 characters or fewer, split only at complete sentence boundaries.
- The API returns only these error codes: `ROUTE_UNAVAILABLE`, `SCRIPT_GENERATION_FAILED`, `SPEECH_SYNTHESIS_FAILED`, `CAPSULE_TOO_LONG`, `AUDIO_UNAVAILABLE`. Never leak provider response bodies, voice IDs, or raw provider error text to the client.
- **Out of scope for this MVP:** Hindi, two-host conversations, current-location shortcut, playback speed control, and the regenerate action.

---

## Override Table

| Base plan location | Replace with |
| --- | --- |
| Header **Tech Stack**, line 9 — "OpenAI Responses API, OpenAI text-to-speech API" | "ElevenLabs Script Agent, ElevenLabs Text to Speech (`eleven_multilingual_v2`)" |
| **File structure**, lines 43-44 — `generation.ts` / `speech.ts` | A single `apps/api/src/providers/elevenlabs.ts` implementing both. Add `apps/api/src/services/segmenter.ts` and `apps/api/src/services/retry.ts`. |
| Header **Architecture**, line 7 — "Expo React Native client" | "bare React Native client" — see Override 4. |
| **File structure**, lines 51-71 — `apps/mobile/app/*` Expo Router screens | `apps/mobile/src/screens/*` with explicit React Navigation registration — see Override 4. |
| **Task 1 Step 4**, line 159 — `language: "en"` | `language: "en-IN"` — see Override 1 for the full replacement type block. |
| **Task 3**, line 312 — `SpeechProvider.synthesize(transcript)` | See Override 3. Synthesis is per-segment and returns ordered segments. |
| **Task 3 Step 3**, line 348 — `const audio = await this.speech.synthesize(script.transcript)` | See Override 3 Step 3. |
| **Task 3 Step 3**, line 360 — OpenAI production providers | The production provider is `ElevenLabsProvider` from Task B. |
| **Task 4 Step 1**, lines 409-413 — `create-expo-app`, Expo Router, Expo Audio | See Override 4. |
| **Task 5 Step 4**, line 531 — `language: "en"` | `language: "en-IN"` |
| **Task 6 Step 3**, line 622 — Expo Audio, speed selection | `react-native-track-player`; speed control is out of MVP scope. See Override 6. |
| **Task 6 Step 4**, line 632 — Expo document directory | `react-native-blob-util` document directory. See Override 6. |
| **Task 6 Step 5**, line 636 — `npx expo start --clear` | `npm run ios --workspace @commute-capsule/mobile` or `npm run android --workspace @commute-capsule/mobile` |
| **Task 6** — single `audioUrl` playback | See Override 6 and Task C. Playback is an ordered segment queue. |
| **Task 7 Step 4**, line 713 — `OPENAI_API_KEY` | `ELEVENLABS_API_KEY`, `ELEVENLABS_SCRIPT_AGENT_ID`, `ELEVENLABS_ENGLISH_VOICE_ID`, `ELEVENLABS_TTS_MODEL` |
| **Task 8 Step 1**, line 749 — `language: "en"` | `language: "en-IN"` |

---

## Override 1: Domain Types (replaces Base Task 1, Step 4)

The duration rule and its test are unchanged. Replace the type block only.

- [ ] **Step 4 (replacement): Implement the shared models and duration rule.**

```ts
export const transportModes = [
  "metro", "bus", "local_train", "car", "bike", "walk", "other",
] as const;
export type TransportMode = (typeof transportModes)[number];

export type ListeningStyle = "quick_overview" | "learn_deeply";

export type Language = "en-IN";

export interface TripDraft {
  startLabel: string;
  endLabel: string;
  transportMode: TransportMode;
  estimatedSeconds?: number;
  manualSeconds?: number;
}

export interface RouteEstimate {
  durationSeconds: number;
  summary: string;
  source: "routing" | "manual";
}

export interface CreateCapsuleRequest {
  trip: TripDraft;
  topic: string;
  style: ListeningStyle;
  language: Language;
}

export interface AudioSegment {
  index: number;
  url: string;
  durationSeconds: number;
}

export interface Capsule {
  id: string;
  title: string;
  topic: string;
  language: Language;
  targetSeconds: number;
  audioSeconds: number;
  transcript: string;
  segments: AudioSegment[];
  createdAt: string;
}

export const capsuleErrorCodes = [
  "ROUTE_UNAVAILABLE",
  "SCRIPT_GENERATION_FAILED",
  "SPEECH_SYNTHESIS_FAILED",
  "CAPSULE_TOO_LONG",
  "AUDIO_UNAVAILABLE",
] as const;
export type CapsuleErrorCode = (typeof capsuleErrorCodes)[number];

export function calculateTargetSeconds(tripSeconds: number): number {
  const buffer = Math.min(Math.max(Math.round(tripSeconds * 0.1), 60), 180);
  return Math.max(60, tripSeconds - buffer);
}
```

Note the removal of `audioUrl` in favour of `segments`. Every later reference to `capsule.audioUrl` in the base plan becomes `capsule.segments`.

---

## Task A: Sentence-Safe Segmenter

Slots in after Base Task 2.

**Files:**
- Create: `apps/api/src/services/segmenter.ts`
- Create: `apps/api/src/services/retry.ts`
- Test: `apps/api/tests/segmenter.test.ts`
- Test: `apps/api/tests/retry.test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `splitIntoSegments(text: string, maxChars: number): string[]` and `withRetry<T>(fn: () => Promise<T>, attempts?: number, baseDelayMs?: number): Promise<T>`, both consumed by the capsule service in Override 3.

- [ ] **Step 1: Write the failing segmenter tests.**

```ts
import { describe, it, expect } from "vitest";
import { splitIntoSegments } from "../src/services/segmenter";

describe("splitIntoSegments", () => {
  it("packs whole sentences up to the limit", () => {
    expect(splitIntoSegments("One. Two. Three.", 10)).toEqual(["One. Two.", "Three."]);
  });

  it("returns a single segment when everything fits", () => {
    expect(splitIntoSegments("Only one sentence here.", 8000)).toEqual([
      "Only one sentence here.",
    ]);
  });

  it("never splits inside a sentence, even when that sentence exceeds the limit", () => {
    const long = `${"word ".repeat(20).trim()}.`;
    const segments = splitIntoSegments(long, 10);
    expect(segments).toEqual([long]);
  });

  it("returns an empty array for blank input", () => {
    expect(splitIntoSegments("   ", 8000)).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the segmenter test to verify it fails.**

Run: `npm run test --workspace @commute-capsule/api -- segmenter.test.ts`

Expected: FAIL with a module-resolution error for `../src/services/segmenter`.

- [ ] **Step 3: Implement the segmenter.**

```ts
// Split points are the whitespace that follows a sentence terminator. The
// Devanagari danda is included so the same function serves Hindi later.
const SENTENCE_BOUNDARY = /(?<=[.!?।])\s+/;

/**
 * Split text into segments of at most `maxChars`, breaking only at complete
 * sentence boundaries.
 *
 * Ceiling: a single sentence longer than `maxChars` is emitted as its own
 * oversized segment rather than being cut mid-sentence. The provider will
 * reject it and the caller surfaces SPEECH_SYNTHESIS_FAILED. Splitting at
 * clause boundaries is the upgrade path if real scripts ever hit this.
 */
export function splitIntoSegments(text: string, maxChars: number): string[] {
  const sentences = text.trim().split(SENTENCE_BOUNDARY).filter(Boolean);
  const segments: string[] = [];
  let current = "";

  for (const sentence of sentences) {
    if (current && current.length + 1 + sentence.length > maxChars) {
      segments.push(current);
      current = sentence;
    } else {
      current = current ? `${current} ${sentence}` : sentence;
    }
  }

  if (current) segments.push(current);
  return segments;
}
```

- [ ] **Step 4: Run the segmenter test to verify it passes.**

Run: `npm run test --workspace @commute-capsule/api -- segmenter.test.ts`

Expected: PASS, 4 tests.

- [ ] **Step 5: Write the failing retry tests.**

```ts
import { describe, it, expect, vi } from "vitest";
import { withRetry } from "../src/services/retry";

describe("withRetry", () => {
  it("returns the first successful result without retrying", async () => {
    const fn = vi.fn().mockResolvedValue("ok");
    await expect(withRetry(fn, 3, 1)).resolves.toBe("ok");
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it("retries until it succeeds", async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error("429"))
      .mockResolvedValue("ok");
    await expect(withRetry(fn, 3, 1)).resolves.toBe("ok");
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it("rethrows the last error once attempts are exhausted", async () => {
    const fn = vi.fn().mockRejectedValue(new Error("503"));
    await expect(withRetry(fn, 3, 1)).rejects.toThrow("503");
    expect(fn).toHaveBeenCalledTimes(3);
  });
});
```

- [ ] **Step 6: Run the retry test to verify it fails.**

Run: `npm run test --workspace @commute-capsule/api -- retry.test.ts`

Expected: FAIL with a module-resolution error for `../src/services/retry`.

- [ ] **Step 7: Implement bounded exponential backoff.**

```ts
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Retry `fn` with bounded exponential backoff. Rethrows the final error. */
export async function withRetry<T>(
  fn: () => Promise<T>,
  attempts = 3,
  baseDelayMs = 200,
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt < attempts - 1) await sleep(baseDelayMs * 2 ** attempt);
    }
  }

  throw lastError;
}
```

- [ ] **Step 8: Run both tests and the typecheck.**

Run: `npm run test --workspace @commute-capsule/api -- segmenter.test.ts retry.test.ts && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS, 7 tests, no type errors.

- [ ] **Step 9: Commit.**

```bash
git add apps/api/src/services/segmenter.ts apps/api/src/services/retry.ts apps/api/tests/segmenter.test.ts apps/api/tests/retry.test.ts
git commit -m "feat: add sentence-safe segmenter and bounded retry helper"
```

---

## Task B: ElevenLabs Provider

Slots in after Task A.

**Files:**
- Create: `apps/api/src/providers/elevenlabs.ts`
- Modify: `apps/api/src/config.ts`
- Test: `apps/api/tests/elevenlabs.test.ts`

**Interfaces:**
- Consumes: `Language` and `ListeningStyle` from `@commute-capsule/domain`.
- Produces: the `ContentProvider` interface, `ElevenLabsProvider`, and `DevelopmentProvider`, all consumed by the capsule service in Override 3.

- [ ] **Step 1: Write the failing provider tests.**

```ts
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ElevenLabsProvider, parseScriptResponse } from "../src/providers/elevenlabs";

const config = {
  apiKey: "test-key",
  scriptAgentId: "agent-1",
  englishVoiceId: "voice-en",
  ttsModel: "eleven_multilingual_v2",
};

describe("parseScriptResponse", () => {
  it("accepts a well-formed script", () => {
    const parsed = parseScriptResponse('{"title":"Metro Money","transcript":"A sentence."}');
    expect(parsed).toEqual({ title: "Metro Money", transcript: "A sentence." });
  });

  it("strips a markdown fence before parsing", () => {
    const parsed = parseScriptResponse('```json\n{"title":"T","transcript":"Body."}\n```');
    expect(parsed.title).toBe("T");
  });

  it("rejects a response missing the transcript", () => {
    expect(() => parseScriptResponse('{"title":"T"}')).toThrow("SCRIPT_GENERATION_FAILED");
  });

  it("rejects a response that is not JSON at all", () => {
    expect(() => parseScriptResponse("Sure! Here is your script.")).toThrow(
      "SCRIPT_GENERATION_FAILED",
    );
  });
});

describe("ElevenLabsProvider.synthesize", () => {
  beforeEach(() => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => new ArrayBuffer(8),
    }) as unknown as typeof fetch;
  });

  afterEach(() => vi.restoreAllMocks());

  it("sends the configured English voice and model", async () => {
    const provider = new ElevenLabsProvider(config);
    await provider.synthesize("Hello.", "en-IN");

    const [url, init] = (global.fetch as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(url).toContain("voice-en");
    expect(JSON.parse(init.body as string).model_id).toBe("eleven_multilingual_v2");
  });

  it("throws a clean code and never leaks the provider body", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => "invalid api key sk-secret-123",
    }) as unknown as typeof fetch;

    const provider = new ElevenLabsProvider(config);
    await expect(provider.synthesize("Hello.", "en-IN")).rejects.toThrow(
      /^SPEECH_SYNTHESIS_FAILED$/,
    );
  });
});
```

- [ ] **Step 2: Run the provider test to verify it fails.**

Run: `npm run test --workspace @commute-capsule/api -- elevenlabs.test.ts`

Expected: FAIL with a module-resolution error for `../src/providers/elevenlabs`.

- [ ] **Step 3: Implement the provider.**

```ts
import type { Language, ListeningStyle } from "@commute-capsule/domain";

export interface ScriptRequest {
  topic: string;
  style: ListeningStyle;
  language: Language;
  targetSeconds: number;
  targetWords: number;
}

export interface Script {
  title: string;
  transcript: string;
}

export interface SynthesisResult {
  bytes: Uint8Array;
  durationSeconds: number;
}

export interface ContentProvider {
  generateScript(request: ScriptRequest): Promise<Script>;
  synthesize(text: string, language: Language): Promise<SynthesisResult>;
}

export interface ElevenLabsConfig {
  apiKey: string;
  scriptAgentId: string;
  englishVoiceId: string;
  ttsModel: string;
}

/** Parse the Script Agent reply. Throws SCRIPT_GENERATION_FAILED on any deviation. */
export function parseScriptResponse(raw: string): Script {
  const unfenced = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");

  let parsed: unknown;
  try {
    parsed = JSON.parse(unfenced);
  } catch {
    throw new Error("SCRIPT_GENERATION_FAILED");
  }

  const candidate = parsed as Partial<Script>;
  if (
    typeof candidate?.title !== "string" ||
    typeof candidate?.transcript !== "string" ||
    candidate.title.trim() === "" ||
    candidate.transcript.trim() === ""
  ) {
    throw new Error("SCRIPT_GENERATION_FAILED");
  }

  return { title: candidate.title.trim(), transcript: candidate.transcript.trim() };
}

function buildPrompt(request: ScriptRequest): string {
  return [
    `Write a spoken audio script on the topic: ${request.topic}.`,
    `Style: ${request.style === "quick_overview" ? "a concise overview" : "a structured, deeper explanation"}.`,
    `Language: clear Indian English.`,
    `Length: approximately ${request.targetWords} words, which must be spoken in under ${request.targetSeconds} seconds.`,
    `Structure: a short opening, a useful main explanation, and a natural closing.`,
    `Be factual. Do not present uncertain claims as fact.`,
    `If the topic is unsafe, unreliable, or highly sensitive, return a script that`,
    `politely declines and suggests a safe alternative topic instead.`,
    `Respond with JSON containing exactly two keys, "title" and "transcript".`,
    `Do not use markdown fences, stage directions, or any commentary outside the JSON.`,
  ].join("\n");
}

export class ElevenLabsProvider implements ContentProvider {
  constructor(private readonly config: ElevenLabsConfig) {}

  async generateScript(request: ScriptRequest): Promise<Script> {
    const response = await fetch(
      `https://api.elevenlabs.io/v1/convai/conversations/simulate`,
      {
        method: "POST",
        headers: {
          "xi-api-key": this.config.apiKey,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          agent_id: this.config.scriptAgentId,
          message: buildPrompt(request),
        }),
      },
    );

    if (!response.ok) throw new Error("SCRIPT_GENERATION_FAILED");
    return parseScriptResponse(await response.text());
  }

  async synthesize(text: string, language: Language): Promise<SynthesisResult> {
    const voiceId = this.voiceFor(language);
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: "POST",
        headers: {
          "xi-api-key": this.config.apiKey,
          "content-type": "application/json",
          accept: "audio/mpeg",
        },
        body: JSON.stringify({ text, model_id: this.config.ttsModel }),
      },
    );

    // The provider body may contain the key or voice id. It is never rethrown.
    if (!response.ok) throw new Error("SPEECH_SYNTHESIS_FAILED");

    const bytes = new Uint8Array(await response.arrayBuffer());
    return { bytes, durationSeconds: estimateMp3Seconds(bytes) };
  }

  private voiceFor(language: Language): string {
    if (language === "en-IN") return this.config.englishVoiceId;
    throw new Error("SPEECH_SYNTHESIS_FAILED");
  }
}

/**
 * Duration from encoded size at the provider's default 128 kbps MP3 output.
 * Ceiling: this is an estimate, and the capsule budget is a hard ceiling.
 * Replace with a real MP3 frame count if measured drift ever exceeds a second.
 */
function estimateMp3Seconds(bytes: Uint8Array): number {
  const bitsPerSecond = 128_000;
  return (bytes.byteLength * 8) / bitsPerSecond;
}

/** Deterministic provider for development and tests. Never contacts a network. */
export class DevelopmentProvider implements ContentProvider {
  async generateScript(request: ScriptRequest): Promise<Script> {
    const sentence = `This is a development capsule about ${request.topic}.`;
    // Deliberately undershoot the budget so development output never trips the
    // shortening path and tests assert the happy route.
    const count = Math.max(1, Math.floor((request.targetWords * 0.9) / 8));
    return {
      title: `Development capsule: ${request.topic}`,
      transcript: Array.from({ length: count }, () => sentence).join(" "),
    };
  }

  async synthesize(text: string): Promise<SynthesisResult> {
    const words = text.split(/\s+/).filter(Boolean).length;
    return {
      bytes: new Uint8Array(text.length),
      durationSeconds: (words / 150) * 60,
    };
  }
}
```

- [ ] **Step 4: Run the provider test to verify it passes.**

Run: `npm run test --workspace @commute-capsule/api -- elevenlabs.test.ts`

Expected: PASS, 6 tests.

- [ ] **Step 5: Add the ElevenLabs values to the validated server configuration.**

In `apps/api/src/config.ts`, extend the existing Zod environment schema with these fields, keeping the existing `PROVIDER_MODE`, maps, and S3 entries:

```ts
ELEVENLABS_API_KEY: z.string().min(1),
ELEVENLABS_SCRIPT_AGENT_ID: z.string().min(1),
ELEVENLABS_ENGLISH_VOICE_ID: z.string().min(1),
ELEVENLABS_TTS_MODEL: z.string().default("eleven_multilingual_v2"),
```

These are required only when `PROVIDER_MODE` is `production`, matching the base plan's Task 8 Step 4 startup check.

- [ ] **Step 6: Run the API suite and typecheck.**

Run: `npm run test --workspace @commute-capsule/api && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS, no type errors.

- [ ] **Step 7: Commit.**

```bash
git add apps/api/src/providers/elevenlabs.ts apps/api/src/config.ts apps/api/tests/elevenlabs.test.ts
git commit -m "feat: add ElevenLabs script and speech provider"
```

---

## Override 3: Segmented Capsule Generation (replaces Base Task 3, Steps 1-3)

The base task's Step 4 (`POST /v1/capsules` and its integration test), Step 5, and Step 6 are unchanged apart from asserting `segments` instead of `audioUrl`.

**Interfaces:**
- Consumes: `splitIntoSegments` and `withRetry` from Task A; `ContentProvider` from Task B; `calculateTargetSeconds` from Override 1.
- Consumes: the storage boundary from the base plan's `apps/api/src/providers/storage.ts`, which this plan pins to `interface Storage { put(key: string, bytes: Uint8Array): Promise<string> }`, returning the stored object's URL. `InMemoryStorage` is its test implementation; the S3 adapter is its production implementation.
- Produces: `CapsuleService.create(request: CreateCapsuleRequest, tripSeconds: number): Promise<Capsule>`.

- [ ] **Step 1 (replacement): Write the failing capsule-service tests.**

```ts
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
```

- [ ] **Step 2 (replacement): Run the capsule-service tests to verify they fail.**

Run: `npm run test --workspace @commute-capsule/api -- capsule-service.test.ts`

Expected: FAIL with a module-resolution error for `../src/services/capsule-service`.

- [ ] **Step 3 (replacement): Implement segmented orchestration.**

```ts
import { randomUUID } from "node:crypto";
import {
  calculateTargetSeconds,
  type Capsule,
  type AudioSegment,
  type CreateCapsuleRequest,
} from "@commute-capsule/domain";
import type { ContentProvider } from "../providers/elevenlabs";
import type { Storage } from "../providers/storage";
import { splitIntoSegments } from "./segmenter";
import { withRetry } from "./retry";

const MAX_SEGMENT_CHARS = 8_000;
const WORDS_PER_MINUTE = 150;
const SHORTENING_FACTOR = 0.85;

export class CapsuleService {
  constructor(
    private readonly provider: ContentProvider,
    private readonly storage: Storage,
  ) {}

  async create(request: CreateCapsuleRequest, tripSeconds: number): Promise<Capsule> {
    const targetSeconds = calculateTargetSeconds(tripSeconds);
    const id = randomUUID();

    let targetWords = Math.round((targetSeconds / 60) * WORDS_PER_MINUTE);
    let attempt = 0;

    // One generation attempt, then one shortened retry, then give up.
    while (attempt < 2) {
      const script = await this.provider.generateScript({
        topic: request.topic,
        style: request.style,
        language: request.language,
        targetSeconds,
        targetWords,
      });

      const segments = await this.synthesizeSegments(id, script.transcript, request);
      const audioSeconds = segments.reduce((sum, s) => sum + s.durationSeconds, 0);

      if (audioSeconds <= targetSeconds) {
        return {
          id,
          title: script.title,
          topic: request.topic,
          language: request.language,
          targetSeconds,
          audioSeconds,
          transcript: script.transcript,
          segments,
          createdAt: new Date().toISOString(),
        };
      }

      targetWords = Math.round(targetWords * SHORTENING_FACTOR);
      attempt += 1;
    }

    throw new Error("CAPSULE_TOO_LONG");
  }

  /** Synthesize sequentially so a retry never regenerates a successful segment. */
  private async synthesizeSegments(
    capsuleId: string,
    transcript: string,
    request: CreateCapsuleRequest,
  ): Promise<AudioSegment[]> {
    const texts = splitIntoSegments(transcript, MAX_SEGMENT_CHARS);
    const segments: AudioSegment[] = [];

    for (const [index, text] of texts.entries()) {
      const result = await withRetry(() =>
        this.provider.synthesize(text, request.language),
      );
      const url = await this.storage.put(`${capsuleId}/${index}.mp3`, result.bytes);
      segments.push({ index, url, durationSeconds: result.durationSeconds });
    }

    return segments;
  }
}
```

- [ ] **Step 4: Run the capsule-service tests to verify they pass.**

Run: `npm run test --workspace @commute-capsule/api -- capsule-service.test.ts`

Expected: PASS, 4 tests.

- [ ] **Step 5: Continue with the base plan's Task 3 Steps 4-6**, asserting `segments` rather than `audioUrl` in the HTTP integration test.

---

## Override 4: Bare React Native Client (replaces Base Task 4, Step 1)

The mobile app uses the React Native community CLI. There is no Expo SDK, no Expo Go, and no managed workflow. `ios/` and `android/` are generated at scaffold time and committed.

Building requires the native toolchain: Xcode and CocoaPods for iOS (macOS only), Android Studio with a configured SDK and an emulator or device for Android.

- [ ] **Step 1 (replacement): Scaffold the bare React Native TypeScript app.**

```bash
npx @react-native-community/cli@latest init RidewiseMobile --directory apps/mobile --skip-install
```

Set the package name in `apps/mobile/package.json` to `@commute-capsule/mobile`, and its scripts to:

```json
{
  "test": "jest --runInBand",
  "typecheck": "tsc --noEmit",
  "ios": "react-native run-ios",
  "android": "react-native run-android",
  "start": "react-native start"
}
```

- [ ] **Step 1a: Install client dependencies from the repository root.**

```bash
npm install --workspace @commute-capsule/mobile \
  @react-navigation/native @react-navigation/native-stack \
  react-native-screens react-native-safe-area-context \
  react-native-track-player \
  @react-native-async-storage/async-storage \
  react-native-blob-util \
  zustand @tanstack/react-query
npm install --workspace @commute-capsule/mobile --save-dev \
  @testing-library/react-native @types/jest
```

- [ ] **Step 1b: Install iOS native pods.**

```bash
cd apps/mobile/ios && pod install && cd -
```

Expected: CocoaPods reports the installed pod count with no error. Re-run this after any dependency change that includes native code.

- [ ] **Step 1c: Configure Metro to resolve the workspace domain package.**

Bare React Native's Metro does not follow npm workspace symlinks by default. In `apps/mobile/metro.config.js`:

```js
const path = require("node:path");
const { getDefaultConfig, mergeConfig } = require("@react-native/metro-config");

const workspaceRoot = path.resolve(__dirname, "../..");

module.exports = mergeConfig(getDefaultConfig(__dirname), {
  watchFolders: [workspaceRoot],
  resolver: {
    nodeModulesPaths: [
      path.resolve(__dirname, "node_modules"),
      path.resolve(workspaceRoot, "node_modules"),
    ],
    disableHierarchicalLookup: true,
  },
});
```

Without `watchFolders`, importing `@commute-capsule/domain` fails at bundle time with an unresolved-module error rather than a TypeScript error, which is a confusing failure to debug later.

- [ ] **Step 1d: Configure Jest to use the React Native preset.**

In `apps/mobile/jest.config.js`:

```js
module.exports = {
  preset: "react-native",
  setupFilesAfterEnv: ["@testing-library/react-native/extend-expect"],
  transformIgnorePatterns: [
    "node_modules/(?!(@react-native|react-native|@react-navigation|react-native-track-player)/)",
  ],
};
```

- [ ] **Step 1e: Register the track player service.**

`react-native-track-player` requires a playback service registered at app startup. In `apps/mobile/index.js`, after the existing `AppRegistry.registerComponent` call:

```js
import TrackPlayer from "react-native-track-player";
TrackPlayer.registerPlaybackService(() => require("./src/features/capsules/playback-service"));
```

Create `apps/mobile/src/features/capsules/playback-service.ts`:

```ts
import TrackPlayer, { Event } from "react-native-track-player";

/** Remote controls from the lock screen, notification, and headset buttons. */
module.exports = async function playbackService(): Promise<void> {
  TrackPlayer.addEventListener(Event.RemotePlay, () => TrackPlayer.play());
  TrackPlayer.addEventListener(Event.RemotePause, () => TrackPlayer.pause());
  TrackPlayer.addEventListener(Event.RemoteSeek, ({ position }) =>
    TrackPlayer.seekTo(position),
  );
};
```

Enable background audio: add the `audio` background mode to `apps/mobile/ios/RidewiseMobile/Info.plist` under `UIBackgroundModes`, and add `android:foregroundServiceType="mediaPlayback"` plus the `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission in `apps/mobile/android/app/src/main/AndroidManifest.xml`. A commute app whose audio stops when the screen locks is not shippable.

- [ ] **Step 1f: Verify the scaffold builds and runs.**

Run: `npm run ios --workspace @commute-capsule/mobile`

Expected: the app launches in the simulator showing the default React Native screen.

- [ ] **Steps 2-6: Continue with the base plan's Task 4**, with these substitutions throughout:
  - Screens live in `apps/mobile/src/screens/` — `HomeScreen.tsx`, `ModeScreen.tsx`, `TripCheckScreen.tsx`, `TopicScreen.tsx`, `PlayerScreen.tsx`, `LibraryScreen.tsx` — instead of the Expo Router `app/` directory.
  - Navigation is an explicit native stack in `apps/mobile/src/navigation/RootNavigator.tsx`, not file-based routing.
  - Everything else in the base task — the trip store, typed API client, transport selector, and their tests — is unchanged. Zustand, React Query, AsyncStorage, and React Native Testing Library all work identically outside Expo.

---

## Override 5: Topic Screen Language Literal (replaces Base Task 5, Step 4, line 531)

The topic chips and generation mutation are unchanged. The request body uses:

```ts
language: "en-IN",
```

---

## Task C: Ordered Segment Playback

Slots in before Base Task 6, whose player implementation then builds on this hook.

**Files:**
- Create: `apps/mobile/src/features/capsules/use-segment-queue.ts`
- Test: `apps/mobile/__tests__/use-segment-queue.test.ts`

**Interfaces:**
- Consumes: `AudioSegment` from `@commute-capsule/domain`.
- Produces: `segmentAt(segments: AudioSegment[], positionSeconds: number): { index: number; offsetSeconds: number }`, consumed by the player in Override 6.

- [ ] **Step 1: Write the failing segment-queue tests.**

```ts
import { segmentAt } from "../src/features/capsules/use-segment-queue";

const segments = [
  { index: 0, url: "a.mp3", durationSeconds: 10 },
  { index: 1, url: "b.mp3", durationSeconds: 20 },
  { index: 2, url: "c.mp3", durationSeconds: 30 },
];

describe("segmentAt", () => {
  it("resolves a position inside the first segment", () => {
    expect(segmentAt(segments, 4)).toEqual({ index: 0, offsetSeconds: 4 });
  });

  it("resolves a position inside a later segment", () => {
    expect(segmentAt(segments, 25)).toEqual({ index: 1, offsetSeconds: 15 });
  });

  it("clamps a position past the end to the final segment", () => {
    expect(segmentAt(segments, 999)).toEqual({ index: 2, offsetSeconds: 30 });
  });

  it("clamps a negative position to the start", () => {
    expect(segmentAt(segments, -5)).toEqual({ index: 0, offsetSeconds: 0 });
  });
});
```

- [ ] **Step 2: Run the test to verify it fails.**

Run: `npm run test --workspace @commute-capsule/mobile -- use-segment-queue.test.ts`

Expected: FAIL with a module-resolution error for `../src/features/capsules/use-segment-queue`.

- [ ] **Step 3: Implement position resolution.**

```ts
import type { AudioSegment } from "@commute-capsule/domain";

/**
 * Map an absolute capsule position to the segment that contains it and the
 * offset within that segment. Used for resume and seek across ordered files.
 */
export function segmentAt(
  segments: AudioSegment[],
  positionSeconds: number,
): { index: number; offsetSeconds: number } {
  if (segments.length === 0) return { index: 0, offsetSeconds: 0 };
  if (positionSeconds <= 0) return { index: 0, offsetSeconds: 0 };

  let remaining = positionSeconds;
  for (const segment of segments) {
    if (remaining < segment.durationSeconds) {
      return { index: segment.index, offsetSeconds: remaining };
    }
    remaining -= segment.durationSeconds;
  }

  const last = segments[segments.length - 1];
  return { index: last.index, offsetSeconds: last.durationSeconds };
}
```

- [ ] **Step 4: Run the test to verify it passes.**

Run: `npm run test --workspace @commute-capsule/mobile -- use-segment-queue.test.ts`

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit.**

```bash
git add apps/mobile/src/features/capsules/use-segment-queue.ts apps/mobile/__tests__/use-segment-queue.test.ts
git commit -m "feat: resolve playback position across ordered audio segments"
```

---

## Override 6: Player and Library (amends Base Task 6)

Execute the base task as written, with these changes:

- The capsule store persists `segments: AudioSegment[]`, not `audioUrl`.
- Playback uses `react-native-track-player`, not Expo Audio. Add every segment to the native queue in index order via `TrackPlayer.setQueue(...)`; the player then advances between segments itself, so no manual end-of-segment handling is needed.
- Report progress as the summed duration of completed segments plus `useProgress().position` within the current one.
- Resume and seek use `segmentAt` from Task C to convert an absolute capsule position into `TrackPlayer.skip(index)` followed by `TrackPlayer.seekTo(offsetSeconds)`.
- Download saves every segment file with `react-native-blob-util` to its document directory and, when all are present locally, builds the queue from local `file://` URIs. A capsule counts as downloaded only when every segment file exists.
- Playback speed control is out of MVP scope; omit it from the player.
- The regenerate action is out of MVP scope; omit it from the player.
- Background playback and lock-screen controls come from the service registered in Override 4 Step 1e. Verify manually: start a capsule, lock the device, confirm audio continues and the lock screen shows working play/pause controls.

---

## Override 7: Operations Documentation (amends Base Task 7, Step 4)

The documented environment variables are `GOOGLE_MAPS_API_KEY`, `ELEVENLABS_API_KEY`, `ELEVENLABS_SCRIPT_AGENT_ID`, `ELEVENLABS_ENGLISH_VOICE_ID`, `ELEVENLABS_TTS_MODEL`, `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, and `PROVIDER_MODE`.

The runbook additionally documents that no ElevenLabs value may appear in the mobile bundle or any client-readable configuration, and that the alertable error codes are the five in Global Constraints. It also notes the native build prerequisites from Override 4: Xcode and CocoaPods for iOS, Android Studio for Android — there is no Expo Go shortcut.

---

## Override 8: End-to-End Verification (amends Base Task 8)

The end-to-end test payload uses `language: "en-IN"` and asserts:

- `segments.length >= 1`
- Segment indexes are contiguous from zero
- `audioSeconds <= targetSeconds`
- The response body contains no `voiceId`, no `xi-api-key`, and no provider hostname

The production startup check fails when any of the four ElevenLabs values is absent while `PROVIDER_MODE=production`.

---

## Deferred To Later Plans

These are specced and deliberately excluded here:

- **Hindi** — `specs/2026-08-13-ridewise-elevenlabs-bilingual-design.md`. Requires `Language` to become a union, a Hindi voice ID, and a doubled test matrix.
- **Two-host conversations** — `specs/2026-08-13-ridewise-conversation-capsules-design.md`. Requires the host registry, turn grouping, gap-inclusive duration, and speaker-labelled playback.
- **Current-location shortcut**, **playback speed control**, and **regenerate**.
