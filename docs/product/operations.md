# Ridewise operations runbook

Operating guidance for `apps/api`. `apps/mobile` never holds a provider
credential and never calls a provider directly, so it has no environment
configuration of its own beyond `API_BASE_URL`.

## Environment variables

All of these are **server-only**. None of them may appear in an Expo public
env var, the mobile bundle, or any other client-readable configuration.

| Variable | Required in `production` | Purpose |
|---|---|---|
| `PROVIDER_MODE` | always set | `development` or `production` (see below). Defaults to `development`. |
| `GOOGLE_MAPS_API_KEY` | yes | Google Routes API key used by `GoogleRoutingProvider` for trip estimation. |
| `ELEVENLABS_API_KEY` | yes | ElevenLabs API key for the Script Agent and TTS calls. |
| `ELEVENLABS_SCRIPT_AGENT_ID` | yes | The ElevenLabs Script Agent used to draft capsule transcripts. |
| `ELEVENLABS_ENGLISH_VOICE_ID` | yes | Voice used for `en-IN` synthesis. |
| `ELEVENLABS_TTS_MODEL` | no (has a default) | TTS model id, defaults to `eleven_multilingual_v2`. |
| `S3_ENDPOINT` | yes | Object storage endpoint for published capsule audio. |
| `S3_BUCKET` | yes | Bucket that holds capsule audio segments. |
| `S3_ACCESS_KEY_ID` | yes | Storage credential. |
| `S3_SECRET_ACCESS_KEY` | yes | Storage credential. |

## Provider-mode switching

`PROVIDER_MODE` selects the provider implementation; it is the only thing
that changes between environments, not application code:

- **`development`** (default): never contacts any external API. Routing uses
  `DevelopmentRoutingProvider` (deterministic estimates) and content uses
  `DevelopmentProvider` (deterministic scripts and synthesized-duration
  audio) with `InMemoryStorage`. Safe to run with no credentials at all.
- **`production`**: requires every variable in the table above except
  `ELEVENLABS_TTS_MODEL`. Startup fails fast (config validation) if any
  required variable is missing -- the API will not silently fall back to the
  development provider.

## Object-storage retention

Published capsule audio persists in S3-compatible storage for as long as a
capsule reference to it exists (i.e., indefinitely by default -- there is no
background expiry job in this MVP). If storage costs or compliance require a
retention window, add a scheduled deletion job keyed off `Capsule.createdAt`
rather than deleting eagerly; a capsule's segments must never be removed
while any client could still be resuming or re-downloading it.

## The five alertable error codes

The API's error handler (`apps/api/src/app.ts`) maps every known failure to
exactly one of five codes, returned as `{ code, message }`. There is no
sixth code and no `UNSAFE_TOPIC` code -- an unsafe-topic decline from the
Script Agent is a normal, publishable capsule, not an error.

| Code | HTTP status | Meaning | Alert on |
|---|---|---|---|
| `ROUTE_UNAVAILABLE` | 502 | Routing provider failed and no manual duration was supplied. | Sustained rate increase -- may indicate a Google Routes outage or bad API key. |
| `SCRIPT_GENERATION_FAILED` | 502 | The ElevenLabs Script Agent call failed or returned an unparseable response. | Any sustained rate -- indicates a Script Agent or prompt regression. |
| `SPEECH_SYNTHESIS_FAILED` | 502 | A TTS segment failed synthesis after exhausting retries. | Any sustained rate -- indicates an ElevenLabs TTS outage or bad voice/model id. |
| `CAPSULE_TOO_LONG` | 422 | The script still exceeded the duration budget after one shortening attempt. | High rate on a specific topic pattern -- may indicate the shortening factor needs tuning. |
| `AUDIO_UNAVAILABLE` | n/a (mobile-only) | The native player failed to load or play a capsule's audio (stale URL, network loss, corrupt file). Surfaced entirely client-side via `RetryNotice`; not produced by the API. | Not directly alertable server-side; watch client crash/error reporting if added later. |

Never leak provider response bodies, voice IDs, API keys, or S3 credentials
in a response body for any of the above -- the error handler only ever sends
its own constant, pre-written message strings, and unrecognized errors are
logged server-side and returned to the client as a bare `INTERNAL_ERROR`
with no detail.

## Removing local downloaded files

A user removes a capsule's local downloaded audio from the Library screen,
per capsule -- there is no bulk-clear action in this MVP. Deleting a capsule
from the Library (via its row) removes both the capsule's entry from local
storage and any segment files downloaded to the device's document
directory. Deleting a local download never affects the published copy in
object storage; the capsule remains streamable and re-downloadable
afterward.

## Location and route data

- User location is **optional and never required**. A trip can always be
  entered as free-text start/destination labels; Ridewise never demands
  device location permission to function.
- Route data (start, destination, transport mode, computed duration) should
  not be retained beyond what's needed to support a saved capsule. Once a
  capsule is not saved and not downloaded, its associated route metadata may
  be discarded along with it; there is no separate route-history store to
  purge.

## Native build prerequisites

This project uses the **bare React Native CLI**, not Expo Go -- there is no
"scan a QR code and go" shortcut.

- **iOS**: Xcode and CocoaPods are required. Run `pod install` in
  `apps/mobile/ios` before the first build.
- **Android**: Android Studio (with an SDK and an emulator or device) is
  required.

Building without the native toolchain installed will fail; there is no
managed-workflow fallback.
