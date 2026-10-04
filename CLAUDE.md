# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

The English and Hindi solo-narrated app is implemented in Flutter (`apps/ridewise`), with the route-estimate server in `apps/api` (Fastify) and shared TypeScript types in `packages/domain`; all have passing tests. The React Native app was removed; it remains in git history (last present at commit `59e57d5`). Design specs and plans under `docs/superpowers/` predate the Flutter port and still describe React Native. Two-host conversation capsules are specced but not built.

## On-device generation (read first)

Capsules are made **on the phone** by the Flutter app, not by the server. This supersedes the ElevenLabs decision below for speech and scripts.

- Speech: Kokoro-82M (int8) through the official `sherpa_onnx` Dart package. It exposes the Kokoro `lang` setting, so Hindi works (speaker 31 `hf_alpha`, lang `hi`); English uses speaker 3 `af_heart` with `lexicon-us-en.txt`. Script: Gemma 3 1B (GGUF) through `llamadart`, which downloads prebuilt llama.cpp binaries (no source build). Both models download on first use (about 930 MB).
- Code: `apps/ridewise/lib/generation/`. `pipeline.dart` and `script_writer.dart` are pure and unit-tested with fakes; `native/` holds the adapters (`sherpa_speech`, `llama_model`, `model_files`, `runtime`). `lib/dev/native_check.dart` is a debug entry point that measures them on a device.
- **Part by part:** `pipeline.dart` is an async* stream of `CapsuleUpdate`s. It outlines the talk, then writes, speaks and emits one section at a time; the next section is written while the current one is spoken. The Player opens after the first spoken piece and `PlaybackGrower`/`CapsulePlayback.append` add later pieces; playback pauses (`waitingForMore`) and auto-resumes if it catches up. Word budgets adapt to the measured speaking pace. A piece that would pass the trip-time ceiling is dropped, never played. A failure after the first piece ends the capsule with a notice instead of an error. `GenerationController` (app-level) owns the run so it outlives the Topic screen.
- **Script writer v2** (`script_writer.dart`): the outline is a show plan (`TITLE`/`HOOK`/numbered `heading | points`/`TAKEAWAY`; unsafe topics get a polite redirect). Each section is written under a fixed host persona (`hostPersona`, sent as the system message) with a role (opening hook and preview, middle bridge, final recap), the headings already covered and the last two sentences; `previousText` is the whole text so far. Post-processing: `cleanSection` (markdown, stage directions, chat filler, wrapping quotes), `speakable` (rupee/percent/abbreviations, links, emoji), `dropRepeats`, `ensureBranding` (show name in the opening, fixed sign-off at the end), and one continuation call when a section is under 60% of its word target. A 1B model cannot be trusted with format or branding, so these are enforced in code. Keep it that way when changing prompts.
- The server (`apps/api`) is used only for route-time estimates (the Google Maps key must stay off the device). Its capsule routes and ElevenLabs provider are unused by the app.
- Verified on the Android arm64 emulator (launch it with `-cores 4 -memory 4096`; the Medium_Phone AVD defaults to 1 core and 2 GB and thrashes: a first part took 16+ minutes there and 74-93 seconds with the flags): models download, English and Hindi speak, a 4-minute English capsule generates and plays. The emulator runs speech at roughly 3x slower than real time and varies with host load, so generate ahead of the ride, not while the user waits. Real phone speed, iOS (no Xcode on the dev Mac), and Hindi script quality are unverified; Gemma's Hindi is shallow and partly wrong.

## Provider decision (history; superseded for generation)

Three provider generations exist in the docs. Only the newest is current:

1. `specs/2026-07-29-commute-capsule-india-design.md` + `plans/2026-07-31-commute-capsule-india.md` — original English-only MVP on OpenAI. Still the source of truth for product flow, screens, data model, and the workspace/file structure.
2. `specs/2026-08-06-ridewise-sarvam-bilingual-design.md` + `plans/2026-08-06-ridewise-sarvam-bilingual.md` — **superseded**. Sarvam-30B / Bulbul v3.
3. `specs/2026-08-13-ridewise-elevenlabs-bilingual-design.md` — **current**, status "Ready for review". ElevenLabs Script Agent + `eleven_multilingual_v2`.

The README still describes the Sarvam architecture and is out of date. New work targets ElevenLabs; there is no ElevenLabs implementation plan yet, so the Sarvam plan is the structural template (task shapes, test names, file paths) with the provider swapped.

## Commands

```bash
npm test                                              # api + domain (vitest)
npm run typecheck                                     # api + domain
cd apps/ridewise && flutter test                      # Flutter unit and widget tests
cd apps/ridewise && dart analyze                      # must stay clean
cd apps/ridewise && flutter build apk --debug --target-platform android-arm64   # emulator build (~280 MB APK)
adb reverse tcp:3000 tcp:3000                         # lets the emulator reach the local API
PROVIDER_MODE=development npm run start --workspace @commute-capsule/api        # route estimates
```

On the emulator, `adb shell settings put secure stylus_handwriting_enabled 0` stops Android's stylus tutorial from swallowing `adb shell input text`.

Package names keep the `@commute-capsule/*` scope from the original plan even though the product is now called Ridewise.

## Architecture

`apps/ridewise` (Flutter; `provider` for state, `just_audio` + `just_audio_background` for playback) generates capsules on device and calls `apps/api` (Fastify + Zod) only for route estimates. `packages/domain` (TypeScript) holds the shared types and duration rule for the server; `lib/domain/models.dart` mirrors them in Dart. The Dart and TypeScript copies of the duration rule must stay identical.

The Android project uses `MainActivity : AudioServiceActivity` (needed for lock-screen controls and a single Dart engine). The Flutter app has no custom fonts bundled; it uses the platform serif and sans.

The app never holds a provider credential. The API owns routing. Prompts, segmentation, retries and duration measurement live in `apps/ridewise/lib/generation/` and `lib/domain/text.dart`.

Providers in `apps/api/src/providers/` (routing, generation, speech, storage) have a deterministic `development.ts` used in dev and tests.

### Invariants that drive most of the code

- **Duration budget:** `targetSeconds = max(60, tripSeconds - min(max(round(tripSeconds * 0.1), 60), 180))`. Published audio must never exceed `targetSeconds`. On overrun: one shorter-script regeneration attempt, then a retryable error — never cut audio mid-sentence.
- **Language:** `"en-IN" | "hi-IN"`, chosen explicitly by the user before generation, never inferred from topic text. Transcript language, voice, and stored metadata must always match. Voices are fixed in code (not a user setting in v1).
- **Segmentation:** split only at complete sentence boundaries (English or Devanagari). On device, segments are at most 600 characters so playback can start early and a failed segment is cheap to retry.
- **Segment retry:** a failed speech segment retries independently (3 attempts, exponential backoff); already-successful segments are never regenerated.
- **Failure preserves state:** route or generation failure keeps start, destination, transport mode, duration, topic, style, and language in mobile state so the user retries without re-entry. Manual duration is always available when routing fails.
- **Error surface:** return `ROUTE_UNAVAILABLE`, `SCRIPT_GENERATION_FAILED`, `SPEECH_SYNTHESIS_FAILED`, `CAPSULE_TOO_LONG`, `AUDIO_UNAVAILABLE`. Never leak provider response bodies, voice IDs, or raw error text to the client.
- **Capsule readiness:** not ready until every segment has audio and transcript, language, duration, and audio source are all present.

### Server-only configuration

`ELEVENLABS_API_KEY`, `ELEVENLABS_SCRIPT_AGENT_ID`, `ELEVENLABS_ENGLISH_VOICE_ID`, `ELEVENLABS_HINDI_VOICE_ID`, `ELEVENLABS_TTS_MODEL`, plus S3 and routing settings. None of these may appear in the mobile bundle or any client-readable configuration.

## Working on plans

Plan files use `- [ ]` checkbox steps and are written for TDD: write the failing test, run it, confirm the expected failure message, then implement. Test matrix is English and Hindi independently at 5/10/20/40-minute journeys, with a corpus of station and city names, numbers, currency, abbreviations, and mixed English/Hindi travel terms.
