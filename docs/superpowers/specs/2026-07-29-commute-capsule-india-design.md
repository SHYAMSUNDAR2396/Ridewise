# Commute Capsule India - Design Specification

**Status:** Approved  
**Date:** 2026-07-29  
**Platform:** Mobile application, English-first MVP

## 1. Product Summary

Commute Capsule India turns an upcoming trip into a short, custom audio episode that is designed to finish before the commuter arrives. It addresses the mismatch between short urban journeys and conventional podcasts or audiobooks by creating spoken content matched to the traveller's actual route and available time.

The initial audience is general urban commuters in India. The product supports common commute modes without requiring a single city, metro, rail, or ticketing-system integration.

## 2. Core User Promise

A user enters where they are starting, where they are going, and how they will travel. The app estimates the journey time, lets the user adjust it, and generates an English audio capsule on a selected or custom topic that ends comfortably before arrival.

## 3. MVP Scope

### Included

- Start and destination search, including an optional current-location shortcut.
- Transport modes: metro, bus, local train, cab/car, bike, walk, and other.
- Route-duration estimate with a clear manual duration override.
- Topic suggestions relevant to an Indian urban audience: India and the world, careers, personal finance, technology, history, and language.
- Free-form custom topic entry.
- AI-generated English script, voice audio, and readable transcript.
- Audio playback, playback speed, seeking, resume position, saving, and optional downloading.
- A library of recent and saved capsules.
- Graceful route, generation, and connectivity fallbacks.

### Deferred

- Hindi and regional-language generation.
- Live disruption-aware route changes and automatic episode shortening.
- Social sharing, streaks, subscriptions, and deep personalization.
- Direct integrations with metro, rail, ticketing, or transport-provider systems.

## 4. Primary Journey

1. The user opens the app and enters a start point and destination.
2. The user chooses a travel mode.
3. The app obtains a route estimate and presents its expected duration with an editable time control.
4. The user chooses a suggested topic or enters a custom topic and selects a listening style: quick overview or learn deeply.
5. The app creates a capsule whose target duration is shorter than the available journey time, leaving a small arrival buffer.
6. The user listens, reads the transcript when useful, and can save or download the capsule.
7. The library retains listening progress so playback resumes after an interruption.

Returning users can begin from a prior route or favourite topic, but the MVP does not require an account to complete the core flow.

## 5. Screens and Interaction Design

### Home

The entry point asks, "Where are you headed?" It contains start and destination fields, a current-location shortcut, and access to recently used routes.

### Travel Mode

The user chooses metro, bus, local train, cab/car, bike, walk, or other. The selection informs the route estimate and gives the experience a familiar Indian-commute context.

### Trip Check

The app presents the route summary and estimated time. An editable duration makes the estimate a convenience rather than a blocker.

### Capsule Setup

Topic chips and a custom-topic field let the user decide what to hear. A quick overview style suits short rides; learn deeply provides a more structured explanation for longer trips.

### Player

The player is the visual focus. It provides title, progress, remaining time, large play/pause control, speed control, seeking, transcript, save, and regenerate actions. Route details are secondary while playback is active.

### Library

Recent, saved, and downloaded capsules are available with topic, duration, and listening-progress context.

## 6. System Design

The mobile client coordinates three backend capabilities:

1. **Maps and routing provider:** Place search and travel-time estimates by selected transport mode.
2. **Content-generation service:** Produces a factual, structured script constrained by the selected topic, style, language, and time budget.
3. **Text-to-speech service:** Converts the approved script into streamable/downloadable audio.

The client stores capsule metadata, transcript, playback progress, saved state, and locally downloaded audio. It should retain only the route information needed to create or rediscover a capsule and should make location access optional.

## 7. Content Generation Rules

The generation request contains the selected route context, transport mode, manually adjusted or estimated duration, topic, listening style, and English language setting.

The generation service:

- Uses a measured speaking pace and targets a duration below the available journey time.
- Reserves a brief arrival buffer and includes a clear, natural ending.
- Structures capsules with a concise opening, main explanation, and optional recap.
- Produces a transcript alongside the audio script.
- Avoids presenting uncertain claims as fact and declines unsafe, unreliable, or highly sensitive requests with a helpful alternative-topic suggestion.

For example, a 15-minute estimated trip should normally yield roughly 13 minutes of content plus a concise closing, rather than attempt to fill every second.

## 8. Data Model

Each capsule retains:

- Title and topic
- Start point, destination, selected travel mode, and route-estimate context
- Target duration and actual audio duration
- Script and transcript
- Generated-audio reference or local download reference
- Playback position, saved status, and downloaded status
- Creation time and generation state

The client should persist only the minimum required data and give the user clear controls to remove saved capsules and locally downloaded audio.

## 9. Failure Handling

- **Route lookup fails:** Continue with manual duration entry.
- **Route duration seems inaccurate:** Let the user edit the time before generation.
- **Audio generation is slow:** Make the generated script available first and continue audio generation in the background.
- **Connectivity drops:** Preserve in-progress generation status and allow saved/downloaded capsules to remain playable offline.
- **Trip changes:** Let the user keep the current capsule or regenerate one for a revised duration.
- **Generation fails:** Preserve the selected trip and topic so retrying does not require re-entry.
- **Invalid location or unsupported route:** Explain the issue clearly and offer manual duration as the recovery path.

## 10. Quality and Testing

Testing covers the complete journey for short and medium commute lengths, each transport mode, manual override, invalid locations, route-estimate failures, audio-generation failures, low-connectivity situations, interrupted playback, resume behaviour, transcript visibility, and downloaded-audio playback.

Content quality checks validate that generated episodes:

- Fall within an acceptable tolerance of their target duration.
- End before the stated commute duration.
- Use clear English appropriate for audio-only listening.
- Include a usable transcript.
- Handle unacceptable or unreliable prompts safely.

## 11. Success Criteria

- A new user can start generating a capsule in under one minute.
- The app can complete the core flow even when route estimation is unavailable.
- Capsules finish before the expected arrival time under normal conditions.
- Users can resume, replay, save, and access downloaded audio reliably.

## 12. Decisions Recorded

- The app is an India-focused mobile application, but it is not tied to one city or transport network.
- Users enter a start point, destination, and transport mode; manual duration is a supported override.
- The first release is English-only.
- The selected product direction is a focused, route-aware "Commute Capsule," not a learning-streak or mood-companion product.
