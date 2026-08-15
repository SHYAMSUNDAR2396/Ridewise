# Ridewise — Stitch Prompt (MVP flow, existing visual system)

Paste into the existing project:
`web application/stitch/projects/11008730704357431623/screens/d65620e84b1b4670a478b049fbcc625b`

```
Work inside the existing "Ridewise India" design system already in this
Stitch project. Reuse its established tokens exactly:

- Headline typeface: Newsreader (serif)
- Body/UI typeface: Inter (sans-serif)
- Primary color: Cobalt Blue #2563eb — primary actions, progress
  indicators, branding
- Surface: light neutral #f9f9f9, high-contrast text for outdoor legibility
- Corner radius: ROUND_FOUR
- Overall visual style: clean, spacious, high-contrast, subtle shadows

Do not introduce a new palette, typeface, or corner-radius system. Every
new screen below should look like it belongs in the same app as the
existing Now Playing and Transcript View screens.

===================================================================
IMPORTANT — THIS BUILDS A DIFFERENT FLOW THAN THE EXISTING ONBOARDING
===================================================================
The existing project includes a Welcome screen, a Voice & Language
Selection screen (narrators Aria/Ishaan/Zara), an Interest Mapping
screen, a Contextual Permissions screen, a Live Commute Tracker, an
Expanded Map View, and a Profile & Insights dashboard.

None of these are part of this build. The current product plan has:
- No account and no onboarding flow — a new user's first screen is the
  route-entry screen described below.
- No location-permission request anywhere in the core flow — start and
  destination are typed/searched, not GPS-detected.
- No user-facing voice or narrator picker — voice is chosen
  automatically by the server for consistent quality.
- No live GPS transit tracking and no map view — progress is shown as
  simple elapsed/remaining audio time, not a spatial/transit-stop
  tracker, because there is no real-time transit-data integration.
- No profile, stats dashboard, or streaks.
- Topic and listening style are chosen per trip, at generation time —
  not as a one-time onboarding interest profile.

Reuse the VISUAL LANGUAGE of the existing Now Playing screen (control
layout, button style, progress bar treatment) and the existing
Transcript View (text panel style, typography) as the starting point
for the new Player screen below — but replace their behavior as
specified, dropping the live tracker and map. Do not carry the
onboarding screens, voice picker, map view, or profile dashboard into
this build; treat them as a separate, later phase, not part of this
screen set.

===================================================================
NEW SCREEN 1 — HOME (route entry)
===================================================================
Purpose: "Where are you headed?" — first screen a new user sees, no
account, no permission prompt.

- Header: existing app wordmark, small, top of screen
- Heading: "Where are you headed?" (Newsreader)
- "From" text input, placeholder "Current location or address"
- "To" text input, placeholder "Search destination"
- Both fields open an autocomplete list on focus. No GPS/current-location
  button — typed entry only.
- Horizontally scrollable "Recent routes" row beneath the fields, each
  item a compact card: From → To + last transport-mode icon. Hidden
  entirely (not shown empty) for a first-time user.
- Primary button, full-width, bottom-anchored: "Continue" — disabled
  until both fields are filled.

===================================================================
NEW SCREEN 2 — TRAVEL MODE
===================================================================
- Back navigation
- Heading: "How are you travelling?"
- Grid of 7 single-select cards with icon + label: Metro, Bus, Local
  train, Cab/car, Bike, Walk, Other. Selected = filled with primary
  color; unselected = outlined.
- Primary button, bottom-anchored: "Continue" — disabled until one
  mode is selected.

===================================================================
NEW SCREEN 3 — TRIP CHECK
===================================================================
- Back navigation
- Route summary card: condensed From → To, transport-mode icon + label
- Large, dominant estimated-duration display (e.g. "18 min")
- "Edit" affordance beside the duration opening a time-picker/stepper
  to override it manually
- One line of secondary copy noting this is an estimate and editable
- STATE — route estimate unavailable: replace the duration display
  with a manual-entry time picker, pre-focused, and neutral (not
  alarming) copy such as "We couldn't estimate this route — set your
  travel time." This is a normal path, not an error state.
- Primary button, bottom-anchored: "Continue"

===================================================================
NEW SCREEN 4 — CAPSULE SETUP (per-trip topic and style)
===================================================================
- Back navigation
- Heading: "What do you want to hear about?"
- Topic chips, single-select, pill-shaped: "India and the world",
  "Careers", "Personal finance", "Technology", "History", "Language"
- Custom-topic text input below the chips: "Or type your own topic" —
  selecting a chip clears custom text and vice versa
- Listening style: two large selectable cards, "Quick overview" and
  "Learn deeply," each with one line of explanatory copy
- Language control: English / Hindi segmented control. Render both
  options in the same layout, but visually mark Hindi as disabled /
  "Coming soon" for now — English is the only enabled choice this
  phase, with the layout already correct for enabling Hindi later
  without a redesign.
- Primary button, bottom-anchored: "Generate my capsule" — disabled
  until a topic and a style are selected.
- On tap: transition to a non-blocking "Preparing your capsule…" state
  — a large centered progress indicator with the route/topic summary
  still visible, not a blank spinner screen.
- STATE — generation failed: replace the loading state with copy that
  makes clear nothing needs to be re-entered, e.g. "Something went
  wrong making your capsule," a primary "Retry" button, and a
  secondary "Change topic" action.

===================================================================
NEW SCREEN 5 — PLAYER (adapt existing Now Playing + Transcript View)
===================================================================
Start from the existing Now Playing screen's control layout and the
existing Transcript View's text-panel styling. Remove the live commute
tracker and map view entirely — there is no real-time transit
integration in this build.

- Capsule title, prominent, top of screen (Newsreader)
- Topic and language as small metadata below the title
- Large circular play/pause control, the single largest interactive
  element, centered — reuse existing button treatment
- Progress bar/scrubber with elapsed time (left) and remaining time
  (right) — remaining time matters specifically because the product
  promise is "finishes before arrival"; do not replace this with a
  spatial/stop-based tracker
- Seek by dragging the scrubber
- Transcript toggle revealing the transcript panel (reuse existing
  Transcript View styling), auto-scrolling to the currently-playing
  portion
- Save action (bookmark icon)
- Download action with three states: not downloaded, downloading
  (progress ring), downloaded (filled/checkmark) — "downloaded" only
  once every audio segment is present locally
- STATE — audio unavailable while streaming: replace the play control
  area with a compact inline message and a "Retry" action; preserve
  transcript scroll position if it was open
- Do not include playback-speed control or a "regenerate" action in
  this phase — leave layout room for both without redesign, note this
  as an intentional omission

===================================================================
NEW SCREEN 6 — LIBRARY (replaces topic-categorized Library)
===================================================================
- Segmented tabs at top: "Recent", "Saved", "Downloaded" — replacing
  the existing topic-category grouping
- List rows: title, topic, duration, language, thin progress bar under
  the title if partially listened (no percentage number)
- Downloaded rows show a small offline indicator
- Tapping a row opens the Player screen, resuming from saved position
- Swipe-to-delete or overflow menu with two distinct actions: "Remove
  download" and "Remove from library" — never merge these
- Distinct empty-state copy per tab (not one generic message):
  Recent: "Your listened capsules will show up here"
  Saved: "Nothing saved yet"
  Downloaded: "Download a capsule to listen offline"

===================================================================
CROSS-SCREEN RULES
===================================================================
- Primary action buttons are fixed to the bottom edge on every screen,
  never inline in scrolling content.
- Back navigation on every screen except Home.
- Touch targets sized for one-handed use while walking or standing on
  transit.
- Do not design any location-permission prompt.
- Do not design account creation, login, or an onboarding carousel —
  Home is the first screen a new user sees.
```
