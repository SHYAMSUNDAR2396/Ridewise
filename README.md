# Ridewise

Ridewise is a mobile application that turns a real commute into a complete audio capsule. A commuter enters a start point, destination, transport mode, topic, and preferred language; Ridewise estimates the journey time and creates an episode designed to finish before arrival.

The architecture supports English and Hindi, with a route-first flow and a manual duration fallback for journeys where a route estimate is unavailable. **The initial implementation plan targets an English-only, solo-narrated MVP first** — see [Project Status](#project-status).

## Quickstart

```bash
npm install
PROVIDER_MODE=development npm run dev --workspace @commute-capsule/api
npm run start --workspace @commute-capsule/mobile
```

`PROVIDER_MODE=development` (the default if unset) runs the API against deterministic, no-network development providers — no ElevenLabs, Google Maps, or S3 credentials are required. Run the full test suite with `npm test && npm run typecheck` from the repo root. Building and running the mobile app onto a device or simulator additionally needs the native toolchain (Xcode/CocoaPods for iOS, Android Studio for Android) — see [Planned Technology](#planned-technology).

## Why Ridewise

Short journeys are an awkward fit for most podcasts and audiobooks. A ten-minute metro ride rarely justifies starting a long episode, while reading or watching video can be uncomfortable on the move.

Ridewise makes that time useful with a focused, self-contained listen. Every capsule has a clear opening, a useful core idea, and a natural ending within the time available.

## How It Works

1. Enter a start point and destination.
2. Choose how you are travelling: metro, bus, local train, cab/car, bike, walk, or other.
3. Confirm the estimated travel duration or set it manually.
4. Choose English or Hindi, select a topic, and choose a listening style.
5. Listen to a custom capsule with a matching transcript, playback controls, and optional offline download.

Suggested topics include careers, personal finance, technology, history, India and the world, and language. Users can also enter their own topic.

The designed architecture also supports a **two-host conversation format** — an expert host and a curious host discussing the topic, using server-defined voice personas — as an alternative to solo narration. This format is specced but not part of the initial MVP; see [Documentation](#documentation).

## ElevenLabs at the Core

Ridewise uses [ElevenLabs](https://elevenlabs.io/) exclusively for script generation and speech synthesis.

### Script Generation

The Ridewise API starts a conversation with a configured ElevenLabs Script Agent, sending the selected topic, listening style, language, and the exact audio time budget. The agent returns structured JSON containing a title and transcript. The API validates the response — rejecting malformed JSON, markdown fences, stage directions, and language mismatches — before any audio is synthesized.

### English and Hindi Voices

ElevenLabs Text to Speech, using the `eleven_multilingual_v2` model, converts each script into speech with Indian English (`en-IN`) or Hindi (`hi-IN`). Ridewise selects a quality-tested default voice for each language and retains the selected language with the transcript and audio metadata.

### Reliable Audio for Real Commutes

The API splits scripts at complete sentence boundaries before text-to-speech synthesis. Each speech segment stays within an 8,000-character limit, is retried independently when temporary failures occur, and is stored in order for smooth mobile playback.

Ridewise validates the combined duration before publishing a capsule. If it would exceed the user's available time, the service makes one shorter-script regeneration attempt before returning a retryable error — it never cuts audio mid-sentence.

```text
Ridewise mobile app
  -> Ridewise API
    -> Route estimate or manual duration
    -> ElevenLabs Script Agent generates a bounded, validated script
    -> ElevenLabs Text to Speech (eleven_multilingual_v2) synthesizes English or Hindi audio
    -> Ordered audio segments plus transcript
  -> Streaming or offline playback
```

ElevenLabs credentials remain on the server. The mobile app never receives `ELEVENLABS_API_KEY`, voice IDs, or raw provider errors.

## Product Principles

- **Finish before arrival:** Every capsule reserves an arrival buffer instead of trying to fill every second.
- **Keep the commuter in control:** Route estimates are editable, and manual duration is always available.
- **Make bilingual listening intentional:** English and Hindi are explicit choices before generation.
- **Work through interruptions:** Saved capsules retain language, transcript, progress, and downloaded audio for reliable resume and replay.
- **Fail gracefully:** Route or generation problems preserve the user's journey, duration, topic, style, and language for retry.

## Planned Technology

| Area | Technology |
| --- | --- |
| Mobile app | Bare React Native (community CLI, not Expo), TypeScript, React Navigation |
| Mobile audio | `react-native-track-player`, for a native ordered-segment queue and background/lock-screen playback |
| Mobile persistence | AsyncStorage and `react-native-blob-util` for downloaded audio |
| API | Fastify, TypeScript, Zod |
| Route estimation | Google Maps Routes API, with manual-duration fallback |
| Script generation | ElevenLabs Script Agent |
| Text to speech | ElevenLabs Text to Speech (`eleven_multilingual_v2`) |
| Audio storage | S3-compatible object storage |
| Testing | Vitest, Jest with the `react-native` preset, React Native Testing Library, Maestro |

Building the mobile app requires the native toolchain — Xcode and CocoaPods for iOS, Android Studio for Android. There is no Expo Go shortcut.

## Architecture Notes

The implementation uses a server-side `ElevenLabsProvider` boundary. It exposes separate methods for script generation and speech synthesis so production requests can use ElevenLabs while development and automated tests use a deterministic local provider.

Published capsules include:

- Title, topic, language, target duration, and actual duration
- Transcript in the selected language
- Ordered audio-segment URLs and durations
- Creation time, saved state, download state, and playback position

## Configuration

The server requires the following variables when ElevenLabs integration is enabled:

```bash
ELEVENLABS_API_KEY=your_elevenlabs_api_key
ELEVENLABS_SCRIPT_AGENT_ID=your_script_agent_id
ELEVENLABS_ENGLISH_VOICE_ID=your_english_voice_id
ELEVENLABS_HINDI_VOICE_ID=your_hindi_voice_id
ELEVENLABS_TTS_MODEL=eleven_multilingual_v2
S3_ENDPOINT=your_s3_endpoint
S3_BUCKET=ridewise-audio
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
```

Never add `ELEVENLABS_API_KEY` to the mobile application bundle or any client-readable configuration.

## Project Status

The English-only, solo-narrated MVP described above is implemented and covered by an end-to-end acceptance test (`apps/api/tests/e2e/commute-flow.test.ts`, `apps/mobile/e2e/commute-flow.yaml`).

Three generations of provider architecture exist in the design documents — only the ElevenLabs architecture is current. The initial implementation plan scopes an English-only MVP with solo-narrated capsules; Hindi and the two-host conversation format are fully specced but sequenced as follow-on work.

## Documentation

- [Product design](docs/superpowers/specs/2026-07-29-commute-capsule-india-design.md)
- [ElevenLabs bilingual architecture](docs/superpowers/specs/2026-08-13-ridewise-elevenlabs-bilingual-design.md) — current provider architecture
- [Conversation capsules architecture](docs/superpowers/specs/2026-08-13-ridewise-conversation-capsules-design.md) — two-host format, additive to solo narration
- [ElevenLabs MVP implementation plan](docs/superpowers/plans/2026-08-15-ridewise-elevenlabs-mvp.md) — English-only, solo-narrated scope

## License

License selection is pending before public distribution.
