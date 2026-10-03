# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

The English, solo-narrated MVP is implemented: `apps/mobile` (React Native), `apps/api` (Fastify), `packages/domain`, all with passing tests. Design specs and plans live under `docs/superpowers/`. Hindi and two-host conversation capsules are specced but not built.

## On-device generation (read first)

As of 2026-10, capsules are made **on the phone**, not by the server. This supersedes the ElevenLabs decision below for speech and scripts.

- Speech: Kokoro-82M (int8) through `react-native-sherpa-onnx`. Script: Gemma 3 1B (GGUF) through `llama.rn`. Both models download on first use.
- Code: `apps/mobile/src/features/generation/`. `pipeline.ts` and `script-writer.ts` are pure and unit-tested with fakes; `native/` holds the thin adapters (untested off-device).
- The server (`apps/api`) is now used only for route-time estimates (the Google Maps key must stay off the device). Its capsule routes and ElevenLabs provider are unused by the app.
- **Hindi is blocked:** `react-native-sherpa-onnx` builds the Kokoro config without the `lang` setting Hindi needs, so only English works until that library is patched.
- On-device speech runs at roughly half real time on an M4, so a phone may be near real time. Generate capsules ahead of the ride, not while the user waits.
- Not yet verified on a device or emulator: the native adapters, model downloads, and Gemma script quality.

## Provider decision (superseded for generation, kept for history)

Three provider generations exist in the docs. Only the newest is current:

1. `specs/2026-07-29-commute-capsule-india-design.md` + `plans/2026-07-31-commute-capsule-india.md` — original English-only MVP on OpenAI. Still the source of truth for product flow, screens, data model, and the workspace/file structure.
2. `specs/2026-08-06-ridewise-sarvam-bilingual-design.md` + `plans/2026-08-06-ridewise-sarvam-bilingual.md` — **superseded**. Sarvam-30B / Bulbul v3.
3. `specs/2026-08-13-ridewise-elevenlabs-bilingual-design.md` — **current**, status "Ready for review". ElevenLabs Script Agent + `eleven_multilingual_v2`.

The README still describes the Sarvam architecture and is out of date. New work targets ElevenLabs; there is no ElevenLabs implementation plan yet, so the Sarvam plan is the structural template (task shapes, test names, file paths) with the provider swapped.

## Commands

Planned npm workspaces layout (`apps/*`, `packages/*`):

```bash
npm test                                              # all workspaces
npm run typecheck                                     # all workspaces
npm run test --workspace @commute-capsule/domain      # vitest
npm run test --workspace @commute-capsule/api         # vitest
npm run test --workspace @commute-capsule/mobile      # jest --runInBand (react-native preset)
npm run test --workspace @commute-capsule/api -- segmenter.test.ts   # single test file
maestro test apps/mobile/e2e/bilingual-capsule.yaml   # mobile e2e
```

Package names keep the `@commute-capsule/*` scope from the original plan even though the product is now called Ridewise.

## Architecture

`apps/mobile` (bare React Native — community CLI, React Navigation with bottom tabs, `react-native-track-player`) generates capsules on device; it calls `apps/api` (Fastify + Zod) only for route estimates. `packages/domain` holds shared types, Zod schemas, and the duration rule consumed by both sides.

**Not Expo.** The mobile app uses the bare React Native CLI with `ios/` and `android/` checked in. Older plan text referring to Expo Router, Expo Audio, `create-expo-app`, or `jest-expo` is superseded — see Override 4 in `plans/2026-08-15-ridewise-elevenlabs-mvp.md`. Building it needs the native toolchain (Xcode + CocoaPods for iOS, Android Studio for Android); there is no Expo Go shortcut.

The mobile app never holds a provider credential. The API owns routing. Prompts, segmentation, retries and duration measurement now live in `apps/mobile/src/features/generation/` (the sentence splitter and retry helper are shared from `packages/domain`).

Providers sit behind interfaces in `apps/api/src/providers/` (routing, generation, speech, storage) with a deterministic `development.ts` implementation used in dev and tests — production/test swap is environment config, not code branching.

### Invariants that drive most of the code

- **Duration budget:** `targetSeconds = max(60, tripSeconds - min(max(round(tripSeconds * 0.1), 60), 180))`. Published audio must never exceed `targetSeconds`. On overrun: one shorter-script regeneration attempt, then a retryable error — never cut audio mid-sentence.
- **Language:** `"en-IN" | "hi-IN"`, chosen explicitly by the user before generation, never inferred from topic text. Transcript language, voice, and stored metadata must always match. Voice IDs are server config, not a user setting in v1.
- **Segmentation:** split only at complete sentence boundaries (English or Devanagari). ElevenLabs limit is 8,000 chars/segment (the superseded Sarvam plan used 3,500 — don't copy that number).
- **Segment retry:** a failed synthesis segment retries independently; already-successful segments are never regenerated. Bounded exponential backoff for rate limits and 5xx.
- **Failure preserves state:** route or generation failure keeps start, destination, transport mode, duration, topic, style, and language in mobile state so the user retries without re-entry. Manual duration is always available when routing fails.
- **Error surface:** return `ROUTE_UNAVAILABLE`, `SCRIPT_GENERATION_FAILED`, `SPEECH_SYNTHESIS_FAILED`, `CAPSULE_TOO_LONG`, `AUDIO_UNAVAILABLE`. Never leak provider response bodies, voice IDs, or raw error text to the client.
- **Capsule readiness:** not ready until every segment has audio and transcript, language, duration, and audio source are all present.

### Server-only configuration

`ELEVENLABS_API_KEY`, `ELEVENLABS_SCRIPT_AGENT_ID`, `ELEVENLABS_ENGLISH_VOICE_ID`, `ELEVENLABS_HINDI_VOICE_ID`, `ELEVENLABS_TTS_MODEL`, plus S3 and routing settings. None of these may appear in the mobile bundle or any client-readable configuration.

## Working on plans

Plan files use `- [ ]` checkbox steps and are written for TDD: write the failing test, run it, confirm the expected failure message, then implement. Test matrix is English and Hindi independently at 5/10/20/40-minute journeys, with a corpus of station and city names, numbers, currency, abbreviations, and mixed English/Hindi travel terms.
