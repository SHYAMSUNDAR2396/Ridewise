# Ridewise Sarvam Bilingual Architecture

**Status:** Superseded by the ElevenLabs architecture on 2026-08-13  
**Date:** 2026-08-06  
**Scope:** Replace the planned AI providers with Sarvam AI and launch Ridewise with English and Hindi.

## Product Decision

Ridewise launches with English and Hindi capsules. The user selects English or Hindi when choosing a topic. The selected language applies to the generated script, transcript, voice audio, library metadata, saved capsules, and downloaded audio.

The supported language values are `en-IN` for English and `hi-IN` for Hindi. A user can generate a new capsule in either language for the same route and topic.

## System Architecture

The mobile application continues to call the Ridewise API rather than Sarvam directly. The Ridewise API owns Sarvam credentials, prompt templates, speech segmentation, duration validation, retries, and audio storage.

```text
Mobile app
  -> Ridewise API
    -> routing provider estimates trip duration
    -> Sarvam chat model produces a duration-bounded script
    -> script is split at sentence boundaries
    -> Sarvam Bulbul v3 produces English or Hindi speech segments
    -> API validates combined duration and stores audio plus transcript
  -> Mobile player streams or downloads the finished capsule
```

`SarvamProvider` is the only API provider visible to the capsule-generation service. It exposes separate script-generation and text-to-speech methods, allowing the application to use deterministic development implementations in tests without contacting Sarvam.

## Generation Flow

1. The API receives start point, destination, transport mode, route duration, topic, listening style, and chosen language.
2. The route-duration rule calculates the target audio length with an arrival buffer.
3. A language-specific prompt asks Sarvam to produce a factual, clear script with a short opening, main explanation, and clean ending within the target length.
4. The API stores the resulting script as the transcript.
5. The API divides the script at sentence boundaries into segments no longer than 3,500 characters.
6. Each segment is synthesized with Sarvam Bulbul v3 using `en-IN` or `hi-IN`.
7. The API joins or serves the ordered segments as one capsule, measures the combined duration, and publishes it only when it is no longer than the target duration.

## Language and Voice Rules

- Use one quality-tested default Bulbul v3 speaker for English and one for Hindi in version one.
- Keep the language selector visible before generation; do not infer language from topic text in version one.
- Preserve the selected language in every capsule record.
- Keep the transcript in the generated language so it matches the spoken audio.
- Handle numbers, abbreviations, place names, and topic terms through language-specific prompt instructions and Sarvam text normalisation.
- Voice selection is not a user-facing setting in the first release; it is controlled server-side for consistent quality.

## Reliability Rules

- Split only at complete sentence boundaries; never split a Hindi or English sentence in the middle.
- Retry a failed Sarvam speech segment independently, without regenerating successful segments.
- On a persistent Sarvam failure, retain route, duration, topic, style, and language so the user can retry without re-entry.
- On a route-estimate failure, retain the manual-duration path.
- If the generated speech exceeds the target duration, shorten the final segment or regenerate a shorter script before publishing.
- Do not mark a capsule ready until every segment has audio and the transcript, language, duration, and audio source are present.
- Do not expose Sarvam credentials or raw provider errors to the mobile client.

## Testing

Test English and Hindi separately at 5, 10, 20, and 40-minute trip durations. The test corpus must include common station names, city names, numbers, monetary amounts, abbreviations, topic names, and mixed English/Hindi travel terms.

Automated tests cover:

- Language selection sent from the mobile app to the API.
- `en-IN` and `hi-IN` mapping in `SarvamProvider`.
- Sentence-safe segmentation at the 3,500-character limit.
- Independent retry of a failed speech segment.
- Combined-audio duration never exceeding the capsule target.
- Stored transcript and audio language always matching.
- Manual-duration fallback and retry-state preservation when routing or Sarvam fails.
- Downloaded English and Hindi capsules playing offline.

## Implementation Changes to the Existing Plan

- Replace the OpenAI script-generation and text-to-speech adapters with Sarvam chat and Bulbul v3 adapters.
- Replace the English-only `language: "en"` domain field with the explicit values `"en-IN" | "hi-IN"`.
- Add a language-selection control before generation.
- Add a sentence-aware segmenter, segment retry queue, combined-duration validation, and bilingual test fixtures.
- Configure the server with `SARVAM_API_KEY`; do not ship it to the client.

## Acceptance Criteria

- A user can create a finished English or Hindi capsule for a route without exposing provider credentials.
- The produced transcript uses the selected language and corresponds to the generated audio.
- Published capsules finish within the time budget for the selected trip.
- A failure in one speech segment is retried without discarding successful audio.
- The user can retry after a persistent generation failure without re-entering route, duration, topic, style, or language.
