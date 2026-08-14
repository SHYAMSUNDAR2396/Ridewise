# Ridewise Conversation Capsules Architecture

**Status:** Ready for review
**Date:** 2026-08-13
**Scope:** Add a two-host conversational capsule format alongside solo narration, using ElevenLabs voices and server-defined host personas.

## Product Decision

Ridewise adds a second capsule format. A capsule is either a **solo brief** — the existing single-narrator format — or a **two-host conversation** between an expert host and a curious host. The commuter chooses the format at the topic step, before generation.

Solo remains the default. It is cheaper, faster to generate, and better suited to short journeys where a conversation has no room to develop.

Both formats share the same trip flow, duration budget, error surface, storage, and offline playback. The conversation format changes what the Script Agent returns and how segments map to voices; it does not introduce a parallel pipeline.

## Voice Identity and Consent

Ridewise does not clone the voice of any real person without that person's consent. ElevenLabs enforces verified consent for voice cloning, so an unauthorised likeness of a named podcaster is not a buildable target regardless of product preference.

Two legitimate sources of voice identity exist, and both flow through the same registry:

1. **Original host personas.** Ridewise-owned characters built from a stock ElevenLabs voice plus a written personality. These carry the product at launch.
2. **Licensed iconic voices.** Where ElevenLabs licenses a public figure's voice with their consent, that voice is a registry entry like any other, marked `licensed: true`.

The registry is the extension point. Adding a licensed voice later is a configuration change, not a code change.

## Host Registry

Hosts and pairings are server-side configuration. No host data, voice ID, or persona text reaches the mobile client beyond a display name and blurb.

```ts
interface Host {
  id: string;
  displayName: string;              // "Priya", "Arjun"
  role: "expert" | "curious";
  voiceId: string;                  // server-only
  licensed?: boolean;               // licensed iconic voice
  persona: string;                  // prompt fragment
}

interface Pairing {
  id: string;
  language: "en-IN" | "hi-IN";
  expertId: string;
  curiousId: string;
  blurb: string;                    // shown in the picker
}
```

`persona` is prose, not code: speaking pace, vocabulary level, how the host reacts to a surprising fact, and two or three verbal habits. Tuning a host means editing a string in a configuration file.

Pairings are curated. The commuter selects a pairing, never two hosts independently — this guarantees voice contrast and complementary personalities, and removes the most common way a user-assembled pair sounds wrong.

Voice selection is not a user-facing setting, consistent with the existing ElevenLabs architecture.

## Dialogue Contract

The two hosts hold fixed roles:

- The **expert** knows the material and explains it.
- The **curious** host asks the questions the listener is already forming, and asks for clarification when the expert moves too fast.

This shape keeps the content factually anchored — one voice owns correctness — and produces a question-and-answer rhythm that stays intelligible on a noisy metro or bus.

The prompt must prevent the two failure modes of this shape: an interview-shaped lecture where the curious host contributes nothing, and manufactured disagreement on topics with no genuine controversy.

## Language Rules

English conversations use Indian English.

Hindi conversations use **natural Hinglish** — hosts mix English terms into Hindi as Indian podcasters actually do. Pure Devanagari dialogue reads as a news bulletin and defeats the purpose of the format.

This is a deliberate, scoped relaxation of the transcript-language rule in the ElevenLabs architecture. That rule remains unchanged for solo capsules. For conversation capsules in `hi-IN`, the transcript may contain Latin-script English terms embedded in Hindi sentences, and the Hindi voice synthesizes the mixed text.

The transcript still corresponds exactly to the spoken audio, and the capsule's stored language remains `hi-IN`.

**This rule depends on an unverified provider behaviour.** See Open Risks.

## Generation Flow

The `targetSeconds` rule is unchanged: `max(60, tripSeconds - min(max(round(tripSeconds * 0.1), 60), 180))`.

1. The API sends the Script Agent the language, topic, listening style, `targetSeconds`, a derived target word count, both host personas, and the expert/curious contract.
2. The Script Agent returns JSON containing `title` and `turns` only, where each turn is `{ speaker: "expert" | "curious", text: string }`.
3. The API validates the response before spending any synthesis budget.
4. `groupTurns(turns)` maps turns to synthesis units.
5. Each unit is synthesized with its host's configured voice ID and stored as an ordered, indexed segment.
6. The API measures each stored segment and computes the total duration.
7. The API publishes only when the total is within `targetSeconds`.

### Script Validation

The API rejects a script response when any of the following holds:

- The payload is not valid JSON matching the `title` and `turns` shape.
- Fewer than two turns are present, or only one speaker appears.
- More than two consecutive turns share a speaker.
- The transcript language does not match the selected language.
- Any turn exceeds 8,000 characters.
- The text contains markdown fences, or stage directions such as `[laughs]` or `*pauses*`.

Stage directions matter specifically because text-to-speech reads them aloud as words.

A validation failure returns `SCRIPT_GENERATION_FAILED`. No new error code is introduced — the failure is retryable and the client behaviour is identical to any other script failure.

### Turn Grouping

`groupTurns` is a single named function with one job: convert an ordered turn list into an ordered list of synthesis units.

In version one it is the identity mapping — one turn becomes one unit, synthesized with one voice. This reuses the existing segment machinery exactly: ordered indexed storage, independent per-segment retry, per-segment duration measurement, and ordered playback all work without modification, because a dialogue turn *is* a segment.

Isolating this function is deliberate. Moving to grouped multi-speaker synthesis later — sending several turns per provider call for genuine conversational interplay — replaces one function and changes no caller.

### Duration Budget

Total duration is:

```
total = sum(segment durations) + gapSeconds * (segmentCount - 1)
```

The inter-turn gaps are audible time and count against the budget. A forty-turn capsule accumulates several seconds of gap; omitting it from the total is a direct route to breaching `targetSeconds`, which is a hard ceiling.

`gapSeconds` is server configuration, in the region of 0.15 to 0.25 seconds.

The target word count sent to the Script Agent is derived from `targetSeconds` using a per-language words-per-minute constant, less the gap allowance. Both constants are tunable configuration seeded from measured output, not fixed literals — the initial estimate will be wrong, and Hindi and English will not share a value.

On overrun, the API makes one shorter-script request and repeats synthesis. If the second attempt still exceeds the budget it returns `CAPSULE_TOO_LONG` rather than cutting audio mid-sentence, matching existing behaviour.

## Playback

Gaps are inserted by the player between segments rather than baked into the audio files. This keeps stored audio tight and makes `gapSeconds` tunable without re-synthesis.

The player displays the current speaker's display name, taken from the playing segment's speaker field. The transcript renders as a list of speaker-labelled turns and scrolls to keep the playing turn visible.

Downloaded conversation capsules play offline with speaker labels and transcript intact.

## Data Model

The capsule record gains:

- `format: "solo" | "conversation"`
- `pairingId` — present only for conversation capsules

Each audio segment gains a `speaker` field identifying which host produced it. All other capsule and segment fields are unchanged.

## Reliability

All existing reliability rules carry over unchanged: independent retry of a failed synthesis segment, bounded exponential backoff for rate limiting and service errors, preservation of start, destination, transport mode, duration, topic, style, and language after a failure, and the manual-duration path when route estimation fails.

Format and pairing selections are preserved on failure alongside the existing fields, so a retry requires no re-entry.

No voice ID, persona text, provider response body, or raw provider error reaches the client.

## Testing

Test English and Hindi conversations independently at 5, 10, 20, and 40-minute target journeys.

Automated tests cover:

- `groupTurns` identity behaviour, and grouped behaviour when the seam is used
- Total duration includes inter-turn gaps
- Speaker-to-voice-ID mapping for each language
- Script validation rejects markdown fences, stage directions, single-speaker output, and mismatched language
- A failed turn retries without discarding completed segments
- Format and pairing survive a generation failure
- Speaker labels and turn-structured transcript render correctly
- Offline playback of a downloaded conversation capsule

One quality gate is manual and cannot be automated: listening to Hindi conversation output to confirm the code-mixed text sounds natural.

## Configuration

Existing ElevenLabs, storage, and routing configuration is unchanged. Added server-side configuration:

- Host registry — hosts and curated pairings per language
- `gapSeconds`
- Words-per-minute constant per language

## Out of Scope

- User-assembled pairings, and user-facing voice selection
- Interruptions, overlapping speech, and crosstalk
- More than two speakers
- Emotion and audio tags
- Actual licensed iconic voices — the registry slot exists; no voice is licensed at launch

## Open Risks

**Hinglish synthesis quality is unverified.** The entire Hindi language decision rests on whether the configured Hindi voice pronounces Latin-script English words cleanly inside Hindi sentences. This is answerable with a single text-to-speech call against a ten-line mixed-script sample, and must be answered before the format is built. If the result is poor, the fallback is to transliterate English terms into Devanagari, which changes the Script Agent prompt contract.

**Conversation capsules cost roughly twice as much to synthesize as solo capsules** at the same duration, from per-turn call overhead and the same total character count split across more requests.

**Turn-boundary audio may sound clipped.** Per-turn synthesis produces hard cuts with no conversational carry-over. Whether this is acceptable requires listening to real output on a real commute; the `groupTurns` seam exists so the answer can change the implementation cheaply.

## Acceptance Criteria

- A commuter can choose a two-host conversation, select a pairing, and receive a finished capsule in English or Hindi.
- No voice ID, persona text, or provider credential reaches the client.
- Published conversation capsules never exceed `targetSeconds`, with inter-turn gaps counted.
- Segments play in order with correct speaker labels and a matching turn-structured transcript.
- One failed turn retries without discarding completed segments.
- A generation failure preserves format and pairing along with the existing trip and topic selections.
- Solo capsule behaviour is unchanged.
