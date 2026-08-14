# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

Docs only — no application code has been scaffolded yet. Everything here is design specs and implementation plans under `docs/superpowers/`. The commands and file layout below come from those plans; they describe what to create, not what exists.

## Provider decision (read first)

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
npm run test --workspace @commute-capsule/mobile      # jest --runInBand (jest-expo)
npm run test --workspace @commute-capsule/api -- segmenter.test.ts   # single test file
maestro test apps/mobile/e2e/bilingual-capsule.yaml   # mobile e2e
```

Package names keep the `@commute-capsule/*` scope from the original plan even though the product is now called Ridewise.

## Architecture

`apps/mobile` (Expo / React Native / Expo Router) → `apps/api` (Fastify + Zod) → external providers. `packages/domain` holds shared types, Zod schemas, and the duration rule consumed by both sides.

The mobile app never calls a provider directly and never holds a provider credential. The API owns routing, prompts, language-to-voice mapping, segmentation, retries, duration measurement, and storage.

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

`ELEVENLABS_API_KEY`, `ELEVENLABS_SCRIPT_AGENT_ID`, `ELEVENLABS_ENGLISH_VOICE_ID`, `ELEVENLABS_HINDI_VOICE_ID`, `ELEVENLABS_TTS_MODEL`, plus S3 and routing settings. None of these may appear in Expo public env vars or the mobile bundle.

## Working on plans

Plan files use `- [ ]` checkbox steps and are written for TDD: write the failing test, run it, confirm the expected failure message, then implement. Test matrix is English and Hindi independently at 5/10/20/40-minute journeys, with a corpus of station and city names, numbers, currency, abbreviations, and mixed English/Hindi travel terms.
