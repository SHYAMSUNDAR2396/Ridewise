# Ridewise ElevenLabs Bilingual Architecture

**Status:** Ready for review  
**Date:** 2026-08-13  
**Scope:** Replace Sarvam AI with ElevenLabs for Ridewise script generation and text-to-speech.

## Product Decision

Ridewise launches English and Hindi commute capsules. Before generating a capsule, the user explicitly selects English or Hindi, a topic, and a listening style. The selected language applies to the script, transcript, speech voice, library metadata, saved capsules, and downloaded audio.

The app sends only the journey, duration, topic, style, and language to the Ridewise API. It never communicates with ElevenLabs directly.

## Provider Architecture

Ridewise uses ElevenLabs exclusively for AI generation:

- An ElevenLabs Script Agent, configured with an ElevenLabs-hosted language model, creates a structured script.
- ElevenLabs Text to Speech uses `eleven_multilingual_v2` to synthesize the script into English or Hindi audio.

The Ridewise API owns all provider calls, prompt templates, language-to-voice mapping, transcript validation, segmentation, retries, duration measurement, and storage. It keeps all ElevenLabs credentials server-side.

```text
Mobile app
  -> Ridewise API
    -> route provider estimates duration, or user provides it manually
    -> ElevenLabs Script Agent produces title and transcript
    -> API validates script and splits it at sentence boundaries
    -> ElevenLabs Multilingual v2 produces ordered MP3 audio segments
    -> API measures total duration and stores transcript plus audio manifest
  -> mobile player streams or downloads the finished capsule
```

The API exposes a single `ElevenLabsProvider` boundary to the capsule service. A deterministic development provider implements the same interface for local development and automated tests.

## Script Generation Contract

The Ridewise API starts a text-based conversation with the configured Script Agent and sends the selected language, topic, listening style, route duration, and calculated target duration. The Script Agent must return JSON containing `title` and `transcript` only.

The API validates the response before synthesizing audio. The prompt requires factual, clear, self-contained narration with a short opening, useful main explanation, and natural ending. It also requires the transcript to use the selected language and prohibits raw provider commentary, markdown fences, and unstructured output.

## Voice and Language Rules

- Use `eleven_multilingual_v2` for stable, longer-form narration.
- Configure one quality-tested English voice and one quality-tested Hindi voice through server-side voice IDs.
- Match text language and voice training: English script with the English voice; Hindi script in Devanagari with the Hindi voice.
- Do not offer voice selection in version one. Voice IDs remain server configuration for consistent quality.
- Store the selected language and transcript with every audio manifest so transcript and speech remain aligned.

## Synthesis and Duration Rules

1. The existing trip-duration rule calculates `targetSeconds` with an arrival buffer.
2. The API splits the validated transcript at complete English or Hindi sentence boundaries.
3. Every text-to-speech segment must be 8,000 characters or fewer, leaving margin below the provider maximum for the selected model.
4. The API synthesizes and stores segments in index order as MP3 audio.
5. The API measures each stored segment and sums the durations.
6. The API publishes the capsule only when the combined duration is less than or equal to `targetSeconds`.
7. When audio exceeds the budget, the API makes one shorter-script request to the Script Agent and repeats synthesis. If the second attempt is still too long, it returns a retryable generation error rather than cutting the audio mid-sentence.

## Reliability and Recovery

- Retry only the failed synthesis segment for temporary ElevenLabs errors, preserving segments that already succeeded.
- Retry temporary provider failures for rate limiting and service errors with bounded exponential backoff.
- Preserve start, destination, travel mode, manual or estimated duration, topic, style, and language in mobile state after a route or generation failure.
- Keep the manual-duration flow available when route estimation fails.
- Do not expose `ELEVENLABS_API_KEY`, provider response bodies, voice IDs, or raw provider error text to the mobile client.
- Return stable application errors: `ROUTE_UNAVAILABLE`, `SCRIPT_GENERATION_FAILED`, `SPEECH_SYNTHESIS_FAILED`, `CAPSULE_TOO_LONG`, and `AUDIO_UNAVAILABLE`.

## Data Model

Each capsule keeps title, topic, selected language, listening style, start, destination, transport mode, route-duration context, target duration, actual duration, complete transcript, ordered audio segments, creation time, generation state, playback position, saved state, and download state.

Each audio segment retains its index, text reference, storage URL, and duration. The mobile client stores local metadata and downloaded audio only as needed for playback. Users can remove saved capsules and downloaded files.

## Testing

Test English and Hindi independently at 5, 10, 20, and 40-minute target journeys. The test corpus must include common station and city names, numbers, currency amounts, abbreviations, topic names, Hindi Devanagari text, and common English/Hindi travel terms.

Automated tests cover English and Hindi Script Agent requests, configured voice mapping, script JSON validation, language matching, sentence-safe segmentation under 8,000 characters, retry of only a failed speech segment, combined audio duration, one shorter-script regeneration attempt, retained retry state, ordered segment playback, transcript display, and offline playback of downloaded capsules.

## Configuration

The API server requires:

- `ELEVENLABS_API_KEY`
- `ELEVENLABS_SCRIPT_AGENT_ID`
- `ELEVENLABS_ENGLISH_VOICE_ID`
- `ELEVENLABS_HINDI_VOICE_ID`
- `ELEVENLABS_TTS_MODEL=eleven_multilingual_v2`

Object-storage and routing-provider settings remain separate server configuration. No ElevenLabs secret is allowed in mobile application configuration or public environment variables.

## Acceptance Criteria

- A user can receive a completed English or Hindi audio capsule without any provider credential reaching the client.
- The stored transcript matches the selected language and the synthesized voice.
- Published capsules never exceed the calculated commute time budget.
- One failed audio segment can retry without discarding completed segments.
- Generation failure preserves the user selections for retry.
- Route estimation failure leaves the user able to choose a manual duration and continue.
