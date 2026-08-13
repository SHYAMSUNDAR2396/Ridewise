# Commute Capsule India Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an English-first mobile MVP that estimates an Indian commuter's route duration and generates a replayable audio capsule which ends before arrival.

**Architecture:** Use an Expo React Native client for the route-to-listening flow and a small Fastify API for routing, script generation, speech synthesis, and audio delivery. Keep third-party providers behind server-side adapters so the app can use a deterministic development provider in tests and exchange it for Google Maps Routes, an LLM, and a text-to-speech service through environment configuration.

**Tech Stack:** TypeScript, npm workspaces, Expo/React Native, Expo Router, Expo Audio, AsyncStorage, Fastify, Zod, Vitest, Jest with `jest-expo`, React Native Testing Library, Google Maps Routes API, OpenAI Responses API, OpenAI text-to-speech API, S3-compatible object storage.

## Global Constraints

- Build a mobile application focused on urban commuters in India without tying it to one city or transport network.
- The initial release is English-only.
- The user enters a start point, destination, and transport mode; a manual duration override must always be available.
- Supported transport choices are metro, bus, local train, cab/car, bike, walk, and other.
- Do not require location permission or an account to complete the core route-to-audio flow.
- Keep maps, AI, text-to-speech, and storage credentials on the server; never bundle them into the mobile application.
- Generate a transcript with every capsule, and retain listening progress, saved state, and downloaded state locally.
- Set `targetSeconds` to `max(60, tripSeconds - min(max(round(tripSeconds * 0.1), 60), 180))`; generated audio must not exceed `targetSeconds`.
- Route lookup, low connectivity, and generation failures must preserve enough user input for a manual-duration retry.
- Use clear English for audio listening and reject unsafe, unreliable, or highly sensitive prompts with a safe topic suggestion.

---

## File Structure

```text
apps/
  api/
    src/
      app.ts                       # Fastify server composition
      config.ts                    # Validated server-only environment configuration
      contracts.ts                 # HTTP schemas built from shared domain types
      routes/
        trips.ts                   # Route estimate endpoint
        capsules.ts                # Capsule creation and audio endpoints
      services/
        trip-service.ts            # Estimate-or-manual trip selection
        capsule-service.ts         # Duration-bounded script and audio orchestration
      providers/
        routing.ts                 # Routing provider interface and Google implementation
        generation.ts              # LLM provider interface and OpenAI implementation
        speech.ts                  # Speech provider interface and OpenAI implementation
        storage.ts                 # Object-storage interface and S3 implementation
        development.ts             # Deterministic local provider implementations
    tests/
      trip-service.test.ts
      capsule-service.test.ts
      app.test.ts
  mobile/
    app/
      _layout.tsx                  # Root navigator and API provider
      index.tsx                    # Start/destination screen
      mode.tsx                     # Transport-mode screen
      trip-check.tsx               # Estimate and duration override screen
      topic.tsx                    # Topic and listening-style screen
      player/[id].tsx              # Audio player and transcript
      library.tsx                  # Recent, saved, and downloaded capsules
    src/
      api/client.ts                # Typed HTTP client
      features/trip/trip-store.ts  # In-progress trip state
      features/trip/trip-form.tsx  # Place search and start/destination controls
      features/capsules/capsule-store.ts # Persisted local capsule library
      features/capsules/player.tsx # Reusable audio playback controls
      components/                  # Small accessible UI controls
    __tests__/
      trip-form.test.tsx
      trip-check.test.tsx
      player.test.tsx
      library.test.tsx
packages/
  domain/
    src/index.ts                   # Shared types, schemas, and duration rule
    src/index.test.ts               # Domain tests
docs/
  product/operations.md            # Provider configuration and recovery runbook
```

## Task 1: Create the Workspace and Shared Domain Contract

**Files:**
- Create: `package.json`
- Create: `tsconfig.base.json`
- Create: `packages/domain/package.json`
- Create: `packages/domain/src/index.ts`
- Create: `packages/domain/src/index.test.ts`
- Create: `apps/api/package.json`
- Create: `apps/mobile/package.json`

**Interfaces:**
- Produces `TransportMode`, `ListeningStyle`, `TripDraft`, `RouteEstimate`, `Capsule`, `CreateCapsuleRequest`, and `calculateTargetSeconds(tripSeconds: number): number` from `@commute-capsule/domain`.
- Consumed by every API service and mobile feature in later tasks.

- [ ] **Step 1: Create the root workspace manifest and baseline TypeScript configuration.**

```json
{
  "name": "commute-capsule-india",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "test": "npm run test --workspaces --if-present",
    "typecheck": "npm run typecheck --workspaces --if-present"
  }
}
```

Use the following scripts in the workspace manifests: `@commute-capsule/domain` and `@commute-capsule/api` use `"test": "vitest run"` and `"typecheck": "tsc --noEmit"`; `@commute-capsule/mobile` uses `"test": "jest --runInBand"` and `"typecheck": "tsc --noEmit"`.

- [ ] **Step 2: Write the failing duration-budget test.**

```ts
import { calculateTargetSeconds } from "./index";

describe("calculateTargetSeconds", () => {
  it("keeps a ten percent buffer, bounded between one and three minutes", () => {
    expect(calculateTargetSeconds(900)).toBe(810);
    expect(calculateTargetSeconds(300)).toBe(240);
    expect(calculateTargetSeconds(3600)).toBe(3420);
  });
});
```

- [ ] **Step 3: Run the domain test to verify it fails because the module does not exist.**

Run: `npm test --workspace @commute-capsule/domain`

Expected: FAIL with a module-resolution error for `./index`.

- [ ] **Step 4: Implement the shared models and duration rule.**

```ts
export const transportModes = [
  "metro", "bus", "local_train", "car", "bike", "walk", "other",
] as const;
export type TransportMode = (typeof transportModes)[number];

export type ListeningStyle = "quick_overview" | "learn_deeply";

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
  language: "en";
}

export interface Capsule {
  id: string;
  title: string;
  topic: string;
  targetSeconds: number;
  audioSeconds: number;
  transcript: string;
  audioUrl: string;
  createdAt: string;
}

export function calculateTargetSeconds(tripSeconds: number): number {
  const buffer = Math.min(Math.max(Math.round(tripSeconds * 0.1), 60), 180);
  return Math.max(60, tripSeconds - buffer);
}
```

- [ ] **Step 5: Run the package tests and typecheck.**

Run: `npm test --workspace @commute-capsule/domain && npm run typecheck --workspace @commute-capsule/domain`

Expected: PASS.

- [ ] **Step 6: Commit the shared contract.**

```bash
git add package.json tsconfig.base.json packages/domain apps/api/package.json apps/mobile/package.json
git commit -m "feat: add commute capsule domain contract"
```

## Task 2: Build the API Shell and Route-Estimate Service

**Files:**
- Create: `apps/api/src/config.ts`
- Create: `apps/api/src/providers/routing.ts`
- Create: `apps/api/src/providers/development.ts`
- Create: `apps/api/src/services/trip-service.ts`
- Create: `apps/api/src/routes/trips.ts`
- Create: `apps/api/src/app.ts`
- Create: `apps/api/tests/trip-service.test.ts`
- Create: `apps/api/tests/app.test.ts`

**Interfaces:**
- Consumes `TripDraft`, `RouteEstimate`, and `TransportMode` from `@commute-capsule/domain`.
- Produces `TripService.estimate(input: TripDraft): Promise<RouteEstimate>` and `POST /v1/trips/estimate`.
- Later tasks consume the selected `RouteEstimate` as the source of the capsule time budget.

- [ ] **Step 1: Write the failing route-service tests for successful routing and manual fallback.**

```ts
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
```

- [ ] **Step 2: Run the route-service test to confirm it fails.**

Run: `npm test --workspace @commute-capsule/api -- tests/trip-service.test.ts`

Expected: FAIL because `TripService` and `RoutingProvider` are undefined.

- [ ] **Step 3: Implement the provider boundary, Google Routes adapter, development adapter, and fallback service.**

```ts
export interface RoutingProvider {
  estimate(input: TripDraft): Promise<{ durationSeconds: number; summary: string }>;
}

export class TripService {
  constructor(private readonly routing: RoutingProvider) {}

  async estimate(input: TripDraft): Promise<RouteEstimate> {
    try {
      const estimate = await this.routing.estimate(input);
      return { ...estimate, source: "routing" };
    } catch (error) {
      if (input.manualSeconds && input.manualSeconds >= 60) {
        return { durationSeconds: input.manualSeconds, summary: "Manual duration", source: "manual" };
      }
      throw error;
    }
  }
}
```

Use the Google Routes API only inside `GoogleRoutingProvider`; map `car`, `bike`, and `walk` to its driving, bicycling, and walking travel modes, and map `metro`, `bus`, and `local_train` to transit. Validate `GOOGLE_MAPS_API_KEY` in `config.ts`. Select `DevelopmentRoutingProvider` when `PROVIDER_MODE=development`; it returns a stable 18-minute estimate based on the submitted labels.

- [ ] **Step 4: Add the Zod request schema, Fastify endpoint, and HTTP integration test.**

```ts
app.post("/v1/trips/estimate", async (request, reply) => {
  const input = tripDraftSchema.parse(request.body);
  return reply.send(await tripService.estimate(input));
});

it("returns a manual estimate when routing is unavailable", async () => {
  const app = buildApp({ tripService: failingService });
  const response = await app.inject({
    method: "POST",
    url: "/v1/trips/estimate",
    payload: { ...draft(), manualSeconds: 900 },
  });
  expect(response.json()).toMatchObject({ durationSeconds: 900, source: "manual" });
});
```

- [ ] **Step 5: Run API tests and typecheck.**

Run: `npm test --workspace @commute-capsule/api && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS.

- [ ] **Step 6: Commit the trip-estimate service.**

```bash
git add apps/api
git commit -m "feat: add route estimate with manual fallback"
```

## Task 3: Implement the Duration-Bounded Capsule Generation Pipeline

**Files:**
- Create: `apps/api/src/providers/generation.ts`
- Create: `apps/api/src/providers/speech.ts`
- Create: `apps/api/src/providers/storage.ts`
- Create: `apps/api/src/services/capsule-service.ts`
- Create: `apps/api/src/routes/capsules.ts`
- Create: `apps/api/tests/capsule-service.test.ts`
- Modify: `apps/api/src/app.ts`

**Interfaces:**
- Consumes `CreateCapsuleRequest`, `RouteEstimate`, and `calculateTargetSeconds`.
- Produces `CapsuleService.create(input: CreateCapsuleRequest): Promise<Capsule>` and `POST /v1/capsules`.
- `GenerationProvider.createScript(input: ScriptRequest): Promise<GeneratedScript>` produces `{ title, transcript, expectedSeconds }`.
- `SpeechProvider.synthesize(transcript: string): Promise<{ bytes: Uint8Array; durationSeconds: number }>`.
- `AudioStorage.put(id: string, audio: Uint8Array): Promise<string>` returns a temporary playback URL.

- [ ] **Step 1: Write failing tests for the time budget, transcript retention, and rejected topic path.**

```ts
it("uses the route budget and returns transcript plus audio URL", async () => {
  const service = createService({ routeSeconds: 900, audioSeconds: 790 });
  const capsule = await service.create(request());
  expect(capsule.targetSeconds).toBe(810);
  expect(capsule.audioSeconds).toBe(790);
  expect(capsule.transcript).toContain("commute");
  expect(capsule.audioUrl).toMatch(/^https:\/\//);
});

it("rejects an unsafe topic before calling the speech provider", async () => {
  const service = createService({ rejectedTopic: true });
  await expect(service.create(request({ topic: "unsafe request" }))).rejects.toThrow("Choose a safe learning topic");
});
```

- [ ] **Step 2: Run the capsule-service tests to verify they fail.**

Run: `npm test --workspace @commute-capsule/api -- tests/capsule-service.test.ts`

Expected: FAIL because `CapsuleService` has not been implemented.

- [ ] **Step 3: Implement providers and orchestration with a strict duration check.**

```ts
export class CapsuleService {
  async create(input: CreateCapsuleRequest): Promise<Capsule> {
    const trip = await this.tripService.estimate(input.trip);
    const targetSeconds = calculateTargetSeconds(trip.durationSeconds);
    const script = await this.generator.createScript({ ...input, targetSeconds });
    if (script.expectedSeconds > targetSeconds) throw new Error("Generated script exceeds trip budget");
    const audio = await this.speech.synthesize(script.transcript);
    if (audio.durationSeconds > targetSeconds) throw new Error("Generated audio exceeds trip budget");
    return {
      id: randomUUID(), title: script.title, topic: input.topic, targetSeconds,
      audioSeconds: audio.durationSeconds, transcript: script.transcript,
      audioUrl: await this.storage.put(randomUUID(), audio.bytes),
      createdAt: new Date().toISOString(),
    };
  }
}
```

Give the LLM prompt the exact target seconds, a clear-English requirement, an opening/body/closing structure, and the instruction to provide a safe alternative suggestion when it cannot cover the requested topic. The development generator returns a deterministic transcript. The production provider calls the OpenAI Responses API, and the production speech provider calls the OpenAI text-to-speech API. Store completed audio through an S3-compatible adapter; use an in-memory storage adapter for tests.

- [ ] **Step 4: Add `POST /v1/capsules` and an integration test that verifies request validation and successful generation.**

```ts
app.post("/v1/capsules", async (request, reply) => {
  const input = createCapsuleSchema.parse(request.body);
  return reply.code(201).send(await capsuleService.create(input));
});

expect(response.statusCode).toBe(201);
expect(response.json()).toEqual(expect.objectContaining({
  targetSeconds: 810,
  transcript: expect.any(String),
  audioUrl: expect.any(String),
}));
```

- [ ] **Step 5: Run the generation and HTTP tests.**

Run: `npm test --workspace @commute-capsule/api && npm run typecheck --workspace @commute-capsule/api`

Expected: PASS.

- [ ] **Step 6: Commit the capsule-generation pipeline.**

```bash
git add apps/api
git commit -m "feat: generate duration bounded audio capsules"
```

## Task 4: Set Up the Expo Client and Trip Entry Flow

**Files:**
- Create: `apps/mobile/app/_layout.tsx`
- Create: `apps/mobile/app/index.tsx`
- Create: `apps/mobile/app/mode.tsx`
- Create: `apps/mobile/src/api/client.ts`
- Create: `apps/mobile/src/features/trip/trip-store.ts`
- Create: `apps/mobile/src/features/trip/trip-form.tsx`
- Create: `apps/mobile/src/components/PrimaryButton.tsx`
- Create: `apps/mobile/__tests__/trip-form.test.tsx`

**Interfaces:**
- Consumes `TripDraft` and `TransportMode` from `@commute-capsule/domain`.
- Produces `useTripStore` with `draft`, `setEndpoints(startLabel, endLabel)`, `setTransportMode(mode)`, and `setManualSeconds(seconds)`.
- `apiClient.estimateTrip(draft: TripDraft): Promise<RouteEstimate>` calls Task 2's API endpoint.
- The next task consumes the store from `trip-check.tsx`.

- [ ] **Step 1: Scaffold the Expo TypeScript app and install client dependencies.**

Run: `npx create-expo-app@latest apps/mobile --template blank-typescript`

Install Expo Router, AsyncStorage, Expo Audio, Zustand, React Query, and the React Native Testing Library using the Expo-compatible package commands. Configure the root workspace so `@commute-capsule/domain` resolves in Metro and TypeScript.

- [ ] **Step 2: Write the failing trip-form test.**

```tsx
it("requires both endpoints before moving to transport selection", async () => {
  const user = userEvent.setup();
  render(<TripForm onContinue={onContinue} />);
  await user.type(screen.getByLabelText("Start"), "Rajiv Chowk");
  await user.press(screen.getByRole("button", { name: "Continue" }));
  expect(onContinue).not.toHaveBeenCalled();
  expect(screen.getByText("Enter a destination")).toBeVisible();
});
```

- [ ] **Step 3: Run the client test to verify it fails.**

Run: `npm test --workspace @commute-capsule/mobile -- trip-form.test.tsx --runInBand`

Expected: FAIL because `TripForm` has not been created.

- [ ] **Step 4: Implement the home form, durable trip store, typed API client, and transport selector.**

```ts
type TripState = {
  draft: Partial<TripDraft>;
  setEndpoints: (startLabel: string, endLabel: string) => void;
  setTransportMode: (transportMode: TransportMode) => void;
  setManualSeconds: (manualSeconds?: number) => void;
};

export const useTripStore = create<TripState>((set) => ({
  draft: {},
  setEndpoints: (startLabel, endLabel) => set((state) => ({ draft: { ...state.draft, startLabel, endLabel } })),
  setTransportMode: (transportMode) => set((state) => ({ draft: { ...state.draft, transportMode } })),
  setManualSeconds: (manualSeconds) => set((state) => ({ draft: { ...state.draft, manualSeconds } })),
}));
```

Use accessible labels `Start`, `Destination`, and `Continue`. Display transport choices as icon-and-label controls in this order: Metro, Bus, Local train, Cab/car, Bike, Walk, Other. A current-location button requests permission only after the user taps it.

- [ ] **Step 5: Run mobile tests and static checks.**

Run: `npm test --workspace @commute-capsule/mobile -- --runInBand && npm run typecheck --workspace @commute-capsule/mobile`

Expected: PASS.

- [ ] **Step 6: Commit the trip-entry flow.**

```bash
git add apps/mobile package-lock.json
git commit -m "feat: add mobile trip entry flow"
```

## Task 5: Add Trip Check, Manual Override, Topic Selection, and Generation States

**Files:**
- Create: `apps/mobile/app/trip-check.tsx`
- Create: `apps/mobile/app/topic.tsx`
- Create: `apps/mobile/src/features/trip/duration-input.tsx`
- Create: `apps/mobile/src/features/capsules/generate-capsule.ts`
- Create: `apps/mobile/__tests__/trip-check.test.tsx`
- Modify: `apps/mobile/src/api/client.ts`
- Modify: `apps/mobile/src/features/trip/trip-store.ts`

**Interfaces:**
- Consumes `useTripStore`, `apiClient.estimateTrip`, and `apiClient.createCapsule`.
- Produces `useGenerateCapsule(): { generate(input: CreateCapsuleRequest): Promise<Capsule>; status: "idle" | "loading" | "error" }`.
- On success, navigates to `/player/[id]` with a complete `Capsule` stored by Task 6.

- [ ] **Step 1: Write failing tests for editable time and a failed route estimate.**

```tsx
it("continues with an edited time when route estimation fails", async () => {
  mockEstimateTrip.mockRejectedValueOnce(new Error("network unavailable"));
  render(<TripCheck />);
  await waitFor(() => expect(screen.getByText("Enter travel time")).toBeVisible());
  await userEvent.setup().clear(screen.getByLabelText("Minutes"));
  await userEvent.setup().type(screen.getByLabelText("Minutes"), "15");
  await userEvent.setup().press(screen.getByRole("button", { name: "Continue" }));
  expect(router.push).toHaveBeenCalledWith("/topic");
});
```

- [ ] **Step 2: Run the Trip Check test and confirm it fails.**

Run: `npm test --workspace @commute-capsule/mobile -- trip-check.test.tsx --runInBand`

Expected: FAIL because the Trip Check screen does not exist.

- [ ] **Step 3: Implement estimate display, manual time control, and retained retry state.**

```tsx
const [minutes, setMinutes] = useState("15");
const seconds = Number(minutes) * 60;
const canContinue = Number.isFinite(seconds) && seconds >= 60;

<TextInput
  accessibilityLabel="Minutes"
  keyboardType="number-pad"
  value={minutes}
  onChangeText={setMinutes}
/>
```

If `estimateTrip` fails, retain start, destination, and transport mode in the store; show the manual control immediately with the message `Route estimate unavailable. Set your travel time.` Do not remove the normal editable duration control after a successful estimate.

- [ ] **Step 4: Implement the topic screen and generation mutation.**

```ts
const topicSuggestions = [
  "India and the world", "Careers", "Personal finance", "Technology", "History", "Language",
];

await apiClient.createCapsule({
  trip: completedTrip,
  topic,
  style,
  language: "en",
});
```

Offer `Quick overview` and `Learn deeply` as a segmented control. Disable Generate until a non-empty topic and a valid duration are present. While the request is running, present a non-blocking `Preparing your capsule` state; on failure, keep all selections and expose a Retry button.

- [ ] **Step 5: Run the focused and complete mobile test suites.**

Run: `npm test --workspace @commute-capsule/mobile -- --runInBand && npm run typecheck --workspace @commute-capsule/mobile`

Expected: PASS.

- [ ] **Step 6: Commit the route-to-generation flow.**

```bash
git add apps/mobile
git commit -m "feat: add duration override and capsule setup"
```

## Task 6: Build Playback, Transcript, and Local Library

**Files:**
- Create: `apps/mobile/app/player/[id].tsx`
- Create: `apps/mobile/app/library.tsx`
- Create: `apps/mobile/src/features/capsules/capsule-store.ts`
- Create: `apps/mobile/src/features/capsules/player.tsx`
- Create: `apps/mobile/src/features/capsules/download.ts`
- Create: `apps/mobile/__tests__/player.test.tsx`
- Create: `apps/mobile/__tests__/library.test.tsx`

**Interfaces:**
- Consumes `Capsule` from `@commute-capsule/domain` and capsule creation output from Task 5.
- Produces `useCapsuleStore` with `upsert(capsule)`, `setProgress(id, seconds)`, `toggleSaved(id)`, `markDownloaded(id, uri)`, and `remove(id)`.
- `CapsulePlayer` accepts `{ capsule: Capsule; initialPositionSeconds: number; onProgress(seconds: number): void }`.

- [ ] **Step 1: Write failing playback-resume and library-persistence tests.**

```tsx
it("starts from persisted progress", async () => {
  render(<CapsulePlayer capsule={capsule} initialPositionSeconds={42} onProgress={vi.fn()} />);
  await waitFor(() => expect(mockPlayFromPosition).toHaveBeenCalledWith(42));
});

it("shows a saved capsule in the library", async () => {
  useCapsuleStore.setState({ capsules: [{ ...capsule, saved: true, progressSeconds: 20 }] });
  render(<LibraryScreen />);
  expect(screen.getByText(capsule.title)).toBeVisible();
  expect(screen.getByText("Saved")).toBeVisible();
});
```

- [ ] **Step 2: Run the player and library tests to confirm the initial failure.**

Run: `npm test --workspace @commute-capsule/mobile -- player.test.tsx library.test.tsx --runInBand`

Expected: FAIL because the player and library modules do not exist.

- [ ] **Step 3: Implement AsyncStorage-backed capsule metadata and audio player controls.**

```ts
export type StoredCapsule = Capsule & {
  progressSeconds: number;
  saved: boolean;
  downloadedUri?: string;
};

export const useCapsuleStore = create(
  persist<LibraryState>(
    (set) => ({
      capsules: [],
      upsert: (capsule) => set((state) => ({
        capsules: [capsule, ...state.capsules.filter((item) => item.id !== capsule.id)],
      })),
      setProgress: (id, progressSeconds) => set((state) => ({
        capsules: state.capsules.map((item) => item.id === id ? { ...item, progressSeconds } : item),
      })),
      toggleSaved: (id) => set((state) => ({
        capsules: state.capsules.map((item) => item.id === id ? { ...item, saved: !item.saved } : item),
      })),
      markDownloaded: (id, downloadedUri) => set((state) => ({
        capsules: state.capsules.map((item) => item.id === id ? { ...item, downloadedUri } : item),
      })),
      remove: (id) => set((state) => ({
        capsules: state.capsules.filter((item) => item.id !== id),
      })),
    }),
    { name: "capsule-library", storage: createJSONStorage(() => AsyncStorage) },
  ),
);
```

Use Expo Audio for play/pause, seek, and 0.75x/1x/1.25x/1.5x speed selection. Persist progress at least every 10 seconds, on pause, and when the app enters the background. The player must display a large play/pause control, elapsed/remaining time, transcript visibility control, Save, Download, and Regenerate actions.

- [ ] **Step 4: Implement downloads and offline source selection.**

```ts
export function playbackSource(capsule: StoredCapsule): string {
  return capsule.downloadedUri ?? capsule.audioUrl;
}
```

Download audio to the Expo document directory and save the resulting local URI with `markDownloaded`. A downloaded capsule remains playable without network access; a streamed capsule shows a retryable connection error when audio cannot load.

- [ ] **Step 5: Run client tests and manually verify the core playback path on an Expo simulator or device.**

Run: `npm test --workspace @commute-capsule/mobile -- --runInBand && npx expo start --clear`

Expected: Automated tests PASS; a capsule can play, pause, seek, resume after reload, save, and use local audio after download.

- [ ] **Step 6: Commit player and library support.**

```bash
git add apps/mobile
git commit -m "feat: add capsule playback and offline library"
```

## Task 7: Add Recovery UI, Content Safety Messages, and Product Operations Documentation

**Files:**
- Create: `apps/mobile/src/components/RetryNotice.tsx`
- Create: `apps/mobile/src/components/EmptyState.tsx`
- Create: `docs/product/operations.md`
- Modify: `apps/api/src/services/capsule-service.ts`
- Modify: `apps/api/src/routes/capsules.ts`
- Modify: `apps/mobile/app/trip-check.tsx`
- Modify: `apps/mobile/app/topic.tsx`
- Modify: `apps/mobile/app/player/[id].tsx`
- Modify: `apps/api/tests/capsule-service.test.ts`
- Modify: `apps/mobile/__tests__/trip-check.test.tsx`
- Modify: `apps/mobile/__tests__/player.test.tsx`

**Interfaces:**
- Consumes `CapsuleService.create`, `useTripStore`, `useGenerateCapsule`, and `useCapsuleStore`.
- Produces a stable error response shape `{ code: "ROUTE_UNAVAILABLE" | "GENERATION_FAILED" | "UNSAFE_TOPIC" | "AUDIO_UNAVAILABLE"; message: string; suggestedTopic?: string }`.
- All client errors must preserve the user's current route, duration, topic, and style for retry.

- [ ] **Step 1: Write failing tests for safe alternatives, retry retention, and failed streamed playback.**

```ts
expect(await response.json()).toEqual(expect.objectContaining({
  code: "UNSAFE_TOPIC",
  suggestedTopic: "The history of Indian railways",
}));
```

```tsx
expect(screen.getByDisplayValue("Personal finance")).toBeVisible();
expect(screen.getByRole("button", { name: "Retry" })).toBeVisible();
```

- [ ] **Step 2: Run the affected API and mobile tests and observe failures.**

Run: `npm test --workspace @commute-capsule/api -- capsule-service.test.ts && npm test --workspace @commute-capsule/mobile -- trip-check.test.tsx player.test.tsx --runInBand`

Expected: FAIL because the standard error codes and retry surfaces have not been implemented.

- [ ] **Step 3: Convert expected failures into the shared error response format.**

```ts
export class CapsuleError extends Error {
  constructor(
    readonly code: "ROUTE_UNAVAILABLE" | "GENERATION_FAILED" | "UNSAFE_TOPIC" | "AUDIO_UNAVAILABLE",
    message: string,
    readonly suggestedTopic?: string,
  ) {
    super(message);
  }
}
```

Map known provider failures to this error in the API error handler. Do not expose provider error text, API keys, or internal request data to the app.

- [ ] **Step 4: Add mobile recovery messages and write the operating runbook.**

```tsx
<RetryNotice
  message={error.message}
  actionLabel="Retry"
  onRetry={generate}
/>
```

Document exact environment variables (`GOOGLE_MAPS_API_KEY`, `OPENAI_API_KEY`, `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, and `PROVIDER_MODE`), provider-mode switching, object-storage retention policy, alertable error codes, and how to remove local downloaded files. The document must explicitly state that user location is optional and route data should not be retained beyond what is needed for saved capsules.

- [ ] **Step 5: Run every test suite and static check.**

Run: `npm test && npm run typecheck`

Expected: PASS.

- [ ] **Step 6: Commit recovery behavior and operations guidance.**

```bash
git add apps/api apps/mobile docs/product
git commit -m "feat: add resilient capsule recovery states"
```

## Task 8: Verify the End-to-End MVP and Prepare a Release Candidate

**Files:**
- Create: `apps/api/tests/e2e/commute-flow.test.ts`
- Create: `apps/mobile/e2e/commute-flow.yaml`
- Modify: `README.md`
- Modify: `apps/mobile/app/_layout.tsx`

**Interfaces:**
- Consumes every API endpoint and mobile navigation screen from Tasks 1 through 7.
- Produces a documented, repeatable development setup and an end-to-end acceptance suite.

- [ ] **Step 1: Write the API end-to-end test for the full creation flow in development provider mode.**

```ts
it("creates an English metro capsule from a route estimate", async () => {
  const app = buildApp({ providerMode: "development" });
  const estimate = await app.inject({ method: "POST", url: "/v1/trips/estimate", payload: metroDraft });
  const capsule = await app.inject({
    method: "POST",
    url: "/v1/capsules",
    payload: { trip: { ...metroDraft, estimatedSeconds: estimate.json().durationSeconds }, topic: "Technology", style: "quick_overview", language: "en" },
  });
  expect(capsule.statusCode).toBe(201);
  expect(capsule.json().audioSeconds).toBeLessThanOrEqual(capsule.json().targetSeconds);
});
```

- [ ] **Step 2: Run the end-to-end test and confirm it fails before the complete composition is wired.**

Run: `npm test --workspace @commute-capsule/api -- tests/e2e/commute-flow.test.ts`

Expected: FAIL until all route and capsule dependencies are passed to `buildApp`.

- [ ] **Step 3: Create the Maestro mobile acceptance flow.**

```yaml
appId: com.commutecapsule.mobile
---
- launchApp
- tapOn: "Start"
- inputText: "Rajiv Chowk"
- tapOn: "Destination"
- inputText: "Noida Sector 18"
- tapOn: "Continue"
- tapOn: "Metro"
- tapOn: "Continue"
- tapOn: "Technology"
- tapOn: "Generate capsule"
- assertVisible: "Transcript"
```

- [ ] **Step 4: Wire development-provider composition, add a production-safe startup check, and document local startup.**

```bash
npm install
PROVIDER_MODE=development npm run dev --workspace @commute-capsule/api
npm run start --workspace @commute-capsule/mobile
```

In production mode, fail server startup with a clear configuration error if any required maps, AI, speech, or S3 value is absent. In development mode, never contact external APIs.

- [ ] **Step 5: Run the acceptance suite, full tests, type checks, and a manual accessibility pass.**

Run: `npm test && npm run typecheck && maestro test apps/mobile/e2e/commute-flow.yaml`

Expected: PASS. Manually verify readable labels, screen-reader names, keyboard-safe input fields, and no blocked path when route lookup or audio playback fails.

- [ ] **Step 6: Commit the release-candidate verification.**

```bash
git add README.md apps/api apps/mobile
git commit -m "test: verify end to end commute capsule flow"
```

## Plan Self-Review

**Spec coverage:**

- Route entry, mode selection, India-wide transport scope, and optional location permission are covered by Task 4.
- Estimated route time and manual override are covered by Tasks 2 and 5.
- English-only topic and listening-style setup is covered by Task 5.
- Duration-matched script, transcript, audio, and safe prompting are covered by Task 3.
- Player, transcript, library, persistence, and downloads are covered by Task 6.
- Routing, generation, connectivity, and streamed-audio failures are covered by Task 7.
- Full-flow testing, accessibility, and release verification are covered by Task 8.

**Placeholder scan:** No unresolved implementation markers or deferred implementation steps remain. Provider configuration is specified as concrete server environment variables and development providers make the complete flow testable without credentials.

**Type consistency:** `TripDraft`, `RouteEstimate`, `CreateCapsuleRequest`, `Capsule`, `TransportMode`, and `calculateTargetSeconds` originate in `@commute-capsule/domain` and are consumed under those exact names throughout the plan.
