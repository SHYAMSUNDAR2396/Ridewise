# Ridewise

Ridewise is a mobile application that turns a real commute into a complete audio capsule. A commuter enters a start point, destination, transport mode, topic, and preferred language; Ridewise estimates the journey time and creates an episode designed to finish before arrival.

The first release supports English and Hindi, with a route-first flow and a manual duration fallback for journeys where a route estimate is unavailable.

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

## Sarvam AI at the Core

Ridewise is designed around [Sarvam AI](https://www.sarvam.ai/), using its India-focused language and voice capabilities to create a natural bilingual listening experience.

### Script Generation

The Ridewise API uses Sarvam-30B to generate structured capsule scripts. The prompt includes the selected topic, listening style, language, and the exact audio time budget. It asks for clear, factual narration with a concise opening, main explanation, and clean closing.

### English and Hindi Voices

Sarvam Bulbul v3 converts each script into speech using Indian English (`en-IN`) or Hindi (`hi-IN`). Ridewise selects a quality-tested default voice for each language and retains the selected language with the transcript and audio metadata.

### Reliable Audio for Real Commutes

The API splits scripts at complete sentence boundaries before text-to-speech synthesis. Each speech segment stays within Sarvam's input limit, is retried independently when temporary failures occur, and is stored in order for smooth mobile playback.

Ridewise validates the combined duration before publishing a capsule. If it would exceed the user's available time, the service shortens the ending or regenerates a more concise script.

```text
Ridewise mobile app
  -> Ridewise API
    -> Route estimate or manual duration
    -> Sarvam-30B generates a bounded script
    -> Sarvam Bulbul v3 synthesizes English or Hindi audio
    -> Ordered audio segments plus transcript
  -> Streaming or offline playback
```

Sarvam credentials remain on the server. The mobile app never receives `SARVAM_API_KEY` or raw provider errors.

## Product Principles

- **Finish before arrival:** Every capsule reserves an arrival buffer instead of trying to fill every second.
- **Keep the commuter in control:** Route estimates are editable, and manual duration is always available.
- **Make bilingual listening intentional:** English and Hindi are explicit choices before generation.
- **Work through interruptions:** Saved capsules retain language, transcript, progress, and downloaded audio for reliable resume and replay.
- **Fail gracefully:** Route or generation problems preserve the user's journey, duration, topic, style, and language for retry.

## Planned Technology

| Area | Technology |
| --- | --- |
| Mobile app | Expo, React Native, TypeScript |
| API | Fastify, TypeScript, Zod |
| Route estimation | Routing provider with manual-duration fallback |
| Script generation | Sarvam-30B chat completions |
| Text to speech | Sarvam Bulbul v3 streaming TTS |
| Audio storage | S3-compatible object storage |
| Client persistence | AsyncStorage and local downloaded audio |
| Testing | Vitest, Jest with `jest-expo`, React Native Testing Library, Maestro |

## Architecture Notes

The implementation uses a server-side `SarvamProvider` boundary. It exposes separate methods for script generation and speech synthesis so production requests can use Sarvam while development and automated tests use deterministic local providers.

Published capsules include:

- Title, topic, language, target duration, and actual duration
- Transcript in the selected language
- Ordered audio-segment URLs and durations
- Creation time, saved state, download state, and playback position

## Configuration

The server requires the following variables when Sarvam integration is enabled:

```bash
SARVAM_API_KEY=your_sarvam_api_key
SARVAM_CHAT_MODEL=sarvam-30b
S3_ENDPOINT=your_s3_endpoint
S3_BUCKET=ridewise-audio
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
```

Never add `SARVAM_API_KEY` to an Expo public environment variable or the mobile application bundle.

## Project Status

Ridewise is currently in the design and implementation-planning stage. The bilingual Sarvam architecture and the implementation plan are approved; application code has not yet been scaffolded.

## Documentation

- [Product design](docs/superpowers/specs/2026-07-29-commute-capsule-india-design.md)
- [Sarvam bilingual architecture](docs/superpowers/specs/2026-08-06-ridewise-sarvam-bilingual-design.md)
- [Sarvam bilingual implementation plan](docs/superpowers/plans/2026-08-06-ridewise-sarvam-bilingual.md)

## License

License selection is pending before public distribution.
