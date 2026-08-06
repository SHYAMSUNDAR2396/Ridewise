# Ridewise Sarvam Bilingual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Sarvam AI generation path that creates time-bounded English and Hindi Ridewise capsules with matching transcripts and playable audio.

**Architecture:** The Expo application sends language, journey, and topic selections only to the Ridewise API. The API uses Sarvam-30B for structured scripts, sentence-splits scripts for Bulbul v3, stores ordered audio segments, and returns a capsule manifest; the mobile player queues those segments as one listening experience.

**Tech Stack:** TypeScript, Expo/React Native, Fastify, Zod, Vitest, Jest with `jest-expo`, Sarvam Chat Completions API, Sarvam Bulbul v3 streaming TTS API, S3-compatible storage.

## Global Constraints

- Launch English and Hindi capsules with `en-IN` and `hi-IN` language values.
- The Ridewise API, never the mobile client, owns `SARVAM_API_KEY`.
- Use `sarvam-30b` for script generation and Bulbul v3 for speech synthesis.
- Keep the selected language, transcript, audio metadata, saved state, and download state with every capsule.
- Split only on sentence boundaries and keep every Bulbul v3 request at or below 3,500 characters.
- A capsule cannot publish if its combined audio duration exceeds `targetSeconds`.
- Preserve journey, duration, topic, style, and language for retry after routing or Sarvam failures.
- Keep the existing manual-duration fallback and route-first flow.

---

## File Structure

```text
packages/domain/src/index.ts                 # Language and segment domain types
apps/api/src/config.ts                       # Server-only Sarvam configuration
apps/api/src/providers/sarvam.ts             # Chat and TTS HTTP adapter
apps/api/src/services/segmenter.ts           # Sentence-safe text segmentation
apps/api/src/services/capsule-service.ts     # Generate, synthesize, validate, store
apps/api/src/routes/capsules.ts              # Bilingual capsule endpoint
apps/api/tests/sarvam.test.ts                # Adapter contract tests
apps/api/tests/segmenter.test.ts             # Boundary and Hindi punctuation tests
apps/api/tests/capsule-service.test.ts       # Retry and duration tests
apps/mobile/app/topic.tsx                    # Language selector
apps/mobile/src/features/capsules/player.tsx # Ordered segment playback
apps/mobile/__tests__/topic.test.tsx         # Language request test
apps/mobile/__tests__/player.test.tsx        # Segment queue playback test
docs/product/sarvam-operations.md            # Configuration and recovery guide
```

### Task 1: Add Bilingual Capsule Contracts and Server Configuration

**Files:**
- Modify: `packages/domain/src/index.ts`
- Modify: `packages/domain/src/index.test.ts`
- Create: `apps/api/src/config.ts`
- Create: `apps/api/tests/config.test.ts`

**Interfaces:**
- Produces `CapsuleLanguage = "en-IN" | "hi-IN"`, `AudioSegment`, and `CreateCapsuleRequest.language: CapsuleLanguage`.
- Produces `loadConfig(env): { sarvamApiKey: string; sarvamChatModel: "sarvam-30b" }`.

- [ ] **Step 1: Write failing contract and configuration tests.**

```ts
it("accepts English and Hindi but rejects an unspecified language", () => {
  expect(capsuleLanguageSchema.parse("en-IN")).toBe("en-IN");
  expect(capsuleLanguageSchema.parse("hi-IN")).toBe("hi-IN");
  expect(() => capsuleLanguageSchema.parse("en")).toThrow();
});

it("rejects missing SARVAM_API_KEY outside development mode", () => {
  expect(() => loadConfig({ NODE_ENV: "production" })).toThrow("SARVAM_API_KEY");
});
```

- [ ] **Step 2: Run the focused tests and verify the failure.**

Run: `npm run test --workspace @commute-capsule/domain -- index.test.ts && npm run test --workspace @commute-capsule/api -- config.test.ts`

Expected: FAIL because language contracts and `loadConfig` do not exist.

- [ ] **Step 3: Implement the exact shared types and validation.**

```ts
export const capsuleLanguageSchema = z.enum(["en-IN", "hi-IN"]);
export type CapsuleLanguage = z.infer<typeof capsuleLanguageSchema>;

export interface AudioSegment {
  index: number;
  text: string;
  audioUrl: string;
  durationSeconds: number;
}

export interface Capsule {
  id: string;
  title: string;
  topic: string;
  language: CapsuleLanguage;
  targetSeconds: number;
  audioSeconds: number;
  transcript: string;
  audioSegments: AudioSegment[];
  createdAt: string;
}
```

Use Zod in `loadConfig` to require `SARVAM_API_KEY` and default `SARVAM_CHAT_MODEL` to `sarvam-30b`.

- [ ] **Step 4: Run tests and typechecks.**

Run: `npm run test --workspace @commute-capsule/domain && npm run test --workspace @commute-capsule/api && npm run typecheck --workspace @commute-capsule/domain && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS.

- [ ] **Step 5: Commit the contracts.**

```bash
git add packages/domain apps/api/src/config.ts apps/api/tests/config.test.ts
git commit -m "feat: add bilingual capsule contracts"
```

### Task 2: Implement the Sarvam Chat and Text-to-Speech Adapter

**Files:**
- Create: `apps/api/src/providers/sarvam.ts`
- Create: `apps/api/tests/sarvam.test.ts`

**Interfaces:**
- Produces `SarvamProvider.generateScript(input: ScriptInput): Promise<GeneratedScript>`.
- Produces `SarvamProvider.synthesizeSegment(input: SpeechInput): Promise<Uint8Array>`.
- `ScriptInput` contains `topic`, `style`, `language`, and `targetSeconds`; `GeneratedScript` contains `title` and `transcript`.

- [ ] **Step 1: Write failing HTTP-adapter tests with mocked `fetch`.**

```ts
it("posts a structured Hindi script request to Sarvam chat", async () => {
  await provider.generateScript({ topic: "भारतीय इतिहास", style: "quick_overview", language: "hi-IN", targetSeconds: 480 });
  expect(fetch).toHaveBeenCalledWith("https://api.sarvam.ai/v1/chat/completions", expect.objectContaining({
    headers: expect.objectContaining({ "api-subscription-key": "test-key" }),
  }));
});

it("streams Bulbul v3 audio using the selected language", async () => {
  await provider.synthesizeSegment({ text: "Welcome to Ridewise.", language: "en-IN" });
  expect(fetch).toHaveBeenCalledWith("https://api.sarvam.ai/text-to-speech/stream", expect.objectContaining({
    method: "POST", body: expect.stringContaining('"target_language_code":"en-IN"'),
  }));
});
```

- [ ] **Step 2: Run the adapter tests and verify the failure.**

Run: `npm run test --workspace @commute-capsule/api -- sarvam.test.ts`

Expected: FAIL because `SarvamProvider` does not exist.

- [ ] **Step 3: Implement Sarvam requests with explicit prompts and response checks.**

```ts
const scriptResponse = await fetch("https://api.sarvam.ai/v1/chat/completions", {
  method: "POST",
  headers: { "Content-Type": "application/json", "api-subscription-key": this.key },
  body: JSON.stringify({
    model: "sarvam-30b",
    temperature: 0.2,
    reasoning_effort: "none",
    response_format: { type: "json_object" },
    messages: [{ role: "system", content: systemPrompt(language, targetSeconds) }, { role: "user", content: topic }],
  }),
});
```

Parse `{ "title": string, "transcript": string }` with Zod. For Bulbul, send `model: "bulbul:v3"`, `target_language_code`, `output_audio_codec: "mp3"`, `speech_sample_rate: 24000`, and `pace: 1`. Treat non-2xx responses as a typed provider error that includes status but excludes response body.

- [ ] **Step 4: Run adapter tests and typecheck.**

Run: `npm run test --workspace @commute-capsule/api -- sarvam.test.ts && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS.

- [ ] **Step 5: Commit the Sarvam adapter.**

```bash
git add apps/api/src/providers/sarvam.ts apps/api/tests/sarvam.test.ts
git commit -m "feat: add Sarvam chat and speech provider"
```

### Task 3: Add Sentence-Safe Segmentation and Bounded Capsule Publishing

**Files:**
- Create: `apps/api/src/services/segmenter.ts`
- Create: `apps/api/tests/segmenter.test.ts`
- Modify: `apps/api/src/services/capsule-service.ts`
- Modify: `apps/api/tests/capsule-service.test.ts`

**Interfaces:**
- Produces `splitForSpeech(transcript: string, maxCharacters: number): string[]`.
- Produces `CapsuleService.create(input): Promise<Capsule>` with ordered `audioSegments`.
- Consumes `SarvamProvider` and `AudioStorage.putSegment(capsuleId, index, audio): Promise<{ audioUrl: string; durationSeconds: number }>`.

- [ ] **Step 1: Write failing segmentation and duration tests.**

```ts
it("keeps Hindi sentences intact under the character limit", () => {
  const segments = splitForSpeech("पहला वाक्य पूरा है। दूसरा वाक्य भी पूरा है।", 25);
  expect(segments).toEqual(["पहला वाक्य पूरा है।", "दूसरा वाक्य भी पूरा है।"]);
});

it("does not publish audio longer than the target", async () => {
  const service = createCapsuleService({ segmentDurations: [350, 140], targetSeconds: 480 });
  await expect(service.create(validRequest())).rejects.toThrow("Capsule exceeds target duration");
});
```

- [ ] **Step 2: Run tests and verify the failure.**

Run: `npm run test --workspace @commute-capsule/api -- segmenter.test.ts capsule-service.test.ts`

Expected: FAIL because the segmenter and bounded segment publishing are missing.

- [ ] **Step 3: Implement sentence splitting and ordered synthesis.**

```ts
export function splitForSpeech(transcript: string, maxCharacters: number): string[] {
  const sentences = transcript.match(/[^.!?।]+[.!?।]+|[^.!?।]+$/gu) ?? [];
  return sentences.reduce<string[]>((segments, rawSentence) => {
    const sentence = rawSentence.trim();
    if (sentence.length > maxCharacters) throw new Error("Sentence exceeds Sarvam speech limit");
    const previous = segments.at(-1);
    if (previous && `${previous} ${sentence}`.length <= maxCharacters) segments[segments.length - 1] = `${previous} ${sentence}`;
    else segments.push(sentence);
    return segments;
  }, []);
}
```

Synthesize and store segments in ascending index order. Sum every stored segment duration before constructing `Capsule`; throw `Capsule exceeds target duration` before returning a record when the sum is too high.

- [ ] **Step 4: Add an independent-segment retry test and implementation.**

```ts
const audio = await retry(async () => provider.synthesizeSegment({ text, language }), { retries: 2, retryOnStatuses: [429, 500, 502, 503, 504] });
```

Verify the test records three attempts for only the failed segment and one attempt for every successful segment.

- [ ] **Step 5: Run all API tests and typechecks.**

Run: `npm run test --workspace @commute-capsule/api && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS.

- [ ] **Step 6: Commit bounded synthesis.**

```bash
git add apps/api/src/services apps/api/tests
git commit -m "feat: add bounded bilingual speech synthesis"
```

### Task 4: Add the Mobile Language Selector and Segment-Queue Player

**Files:**
- Modify: `apps/mobile/app/topic.tsx`
- Modify: `apps/mobile/src/api/client.ts`
- Modify: `apps/mobile/src/features/capsules/capsule-store.ts`
- Modify: `apps/mobile/src/features/capsules/player.tsx`
- Create: `apps/mobile/__tests__/topic.test.tsx`
- Create: `apps/mobile/__tests__/player.test.tsx`

**Interfaces:**
- Produces `selectedLanguage: CapsuleLanguage` in trip setup state, defaulting to `en-IN`.
- Consumes `Capsule.audioSegments` and plays them in `index` order.

- [ ] **Step 1: Write failing language-selection and queue-playback tests.**

```tsx
it("sends Hindi in the capsule request", async () => {
  render(<TopicScreen />);
  await userEvent.setup().press(screen.getByRole("button", { name: "Hindi" }));
  await userEvent.setup().press(screen.getByRole("button", { name: "Generate capsule" }));
  expect(mockCreateCapsule).toHaveBeenCalledWith(expect.objectContaining({ language: "hi-IN" }));
});

it("loads the next segment when the previous segment finishes", async () => {
  render(<CapsulePlayer capsule={capsuleWithTwoSegments} />);
  await act(() => mockAudio.onEnded());
  expect(mockAudio.load).toHaveBeenCalledWith("https://audio.example/segment-1.mp3");
});
```

- [ ] **Step 2: Run mobile tests and verify the failure.**

Run: `npm run test --workspace @commute-capsule/mobile -- topic.test.tsx player.test.tsx`

Expected: FAIL because the language control and segment queue are not implemented.

- [ ] **Step 3: Implement the language control and request shape.**

```tsx
const languages: Array<{ label: string; value: CapsuleLanguage }> = [
  { label: "English", value: "en-IN" },
  { label: "Hindi", value: "hi-IN" },
];
```

Render the values as an accessible segmented control above topic suggestions. Persist the selected language with the draft and include it in `apiClient.createCapsule`.

- [ ] **Step 4: Implement ordered segment playback and resume.**

```ts
const segment = capsule.audioSegments.find((item) => item.index === currentIndex);
await player.load(segment.audioUrl);
await player.play();
```

Persist both `segmentIndex` and `segmentPositionSeconds`. On resume, load that indexed segment and seek to its saved position. Expose one total progress display by adding completed segment durations to the active segment position.

- [ ] **Step 5: Run mobile tests and typecheck.**

Run: `npm run test --workspace @commute-capsule/mobile && npm run typecheck --workspace @commute-capsule/mobile`

Expected: PASS.

- [ ] **Step 6: Commit bilingual playback.**

```bash
git add apps/mobile
git commit -m "feat: add English and Hindi capsule playback"
```

### Task 5: Document Operations and Verify the Bilingual End-to-End Flow

**Files:**
- Create: `docs/product/sarvam-operations.md`
- Create: `apps/api/tests/e2e/bilingual-capsule.test.ts`
- Create: `apps/mobile/e2e/bilingual-capsule.yaml`

**Interfaces:**
- Consumes the completed API and mobile interfaces from Tasks 1 through 4.
- Produces a reproducible development configuration and acceptance test for both languages.

- [ ] **Step 1: Write the failing bilingual API acceptance test.**

```ts
it.each(["en-IN", "hi-IN"] as const)("creates a bounded %s capsule", async (language) => {
  const response = await app.inject({ method: "POST", url: "/v1/capsules", payload: { ...validRequest(), language } });
  expect(response.statusCode).toBe(201);
  expect(response.json()).toEqual(expect.objectContaining({ language, transcript: expect.any(String) }));
  expect(response.json().audioSeconds).toBeLessThanOrEqual(response.json().targetSeconds);
});
```

- [ ] **Step 2: Run the end-to-end test and verify the failure.**

Run: `npm run test --workspace @commute-capsule/api -- bilingual-capsule.test.ts`

Expected: FAIL until the complete bilingual API composition is wired.

- [ ] **Step 3: Add the mobile acceptance flow and operations guide.**

```yaml
appId: com.ridewise.mobile
---
- launchApp
- tapOn: "Hindi"
- tapOn: "Technology"
- tapOn: "Generate capsule"
- assertVisible: "Transcript"
```

Document `SARVAM_API_KEY`, `SARVAM_CHAT_MODEL=sarvam-30b`, expected 429 and 5xx retry behaviour, segment storage lifecycle, and how to test locally with deterministic providers. State explicitly that no Sarvam key is allowed in Expo environment variables or the mobile bundle.

- [ ] **Step 4: Run the complete verification suite.**

Run: `npm test && npm run typecheck && maestro test apps/mobile/e2e/bilingual-capsule.yaml`

Expected: PASS for English and Hindi, including duration validation and retry recovery.

- [ ] **Step 5: Commit release verification.**

```bash
git add docs/product apps/api/tests/e2e apps/mobile/e2e
git commit -m "test: verify bilingual Sarvam commute capsules"
```

## Plan Self-Review

**Spec coverage:** Tasks 1 and 4 implement the two-language product choice; Task 2 implements the server-side Sarvam integration; Task 3 implements sentence-safe segmentation, targeted retries, and duration enforcement; Task 4 stores language and plays ordered audio; Task 5 verifies end-to-end behaviour and operational safeguards.

**Placeholder scan:** All provider endpoints, language values, configuration keys, test commands, and success criteria are concrete.

**Type consistency:** `CapsuleLanguage`, `AudioSegment`, `Capsule`, `SarvamProvider`, `splitForSpeech`, and `CapsuleService.create` use the same names and shapes in every task.
