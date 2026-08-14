# Project Brief: Ridewise

## 1. Product Overview
**Product Name:** Ridewise
**Target Market:** India
**Platform:** Mobile (iOS/Android)
**Value Proposition:** An AI-powered audio companion that creates personalized "audio capsules" perfectly timed to fit the duration of a user's daily commute.

---

## 2. Design System: "Ridewise India"
The design language balances a premium, editorial feel with high-utility interface elements optimized for use in transit.

- **Typography:** 
  - **Headlines:** *Newsreader* (Serif) - Provides a sophisticated, magazine-like quality.
  - **Body/UI:** *Inter* (Sans-serif) - Ensures maximum legibility at a glance.
- **Color Palette:**
  - **Primary:** Cobalt Blue (#2563eb) - Used for primary actions, progress indicators, and branding.
  - **Surface:** Light neutrals (#f9f9f9) with high-contrast text for outdoor readability.
- **Visual Style:** Clean, spacious, and high-contrast. Uses subtle shadows and rounded corners (ROUND_FOUR) for a modern yet approachable feel.

---

## 3. Core Features & Screens

### A. Onboarding Flow
- **Welcome:** High-impact introduction to the "audio journey" concept.
- **Voice & Language Selection:** Personalized narrator choice (Aria, Ishaan, Zara) and multi-language support (English, Hindi).
- **Interest Mapping:** Multi-select grid (Tech, Finance, History, etc.) to seed the AI content engine.
- **Contextual Permissions:** Building trust by explaining the need for location data to calculate commute times.

### B. The Playback Experience
- **Now Playing:** Dynamic player with large, easy-to-tap controls.
- **Live Commute Tracker:** A real-time spatial progress bar integrated into the player, showing current stops and time remaining.
- **Expanded Map View:** A high-contrast map interface prioritizing route clarity and "Next Stop" information, with a persistent mini-player.
- **Transcript View:** Synchronized text for users who prefer to read along or reference details.

### C. Personalization & Library
- **Library:** Organized access to saved capsules, categorized by topic.
- **Profile & Insights:** A dashboard showing "Commute Stats" (Total Capsules, Time Saved) and deep preference settings.

---

## 4. User Journey
1. **Discover:** User opens the app and sets their destination.
2. **Generate:** Ridewise calculates the travel time and curates an audio capsule (e.g., 18 minutes of Tech + World News).
3. **Engage:** User listens while tracking their transit progress on the integrated live tracker.
4. **Reflect:** After the ride, the user can save the capsule or view their updated commute statistics.

---

## 5. Technical Considerations
- **Dynamic Content Generation:** AI-driven synthesis of news, podcasts, and briefings.
- **Real-time Transit Data:** Integration with local transit APIs (e.g., Delhi Metro, local bus networks) for accurate time-to-stop calculations.
- **Offline Mode:** Auto-downloading of capsules to ensure uninterrupted playback in low-connectivity areas like metro tunnels.