---
name: Ridewise India Audio Companion
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#434655'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f0f1f1'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#b90538'
  on-secondary: '#ffffff'
  secondary-container: '#dc2c4f'
  on-secondary-container: '#fffbff'
  tertiary: '#555555'
  on-tertiary: '#ffffff'
  tertiary-container: '#6e6d6d'
  on-tertiary-container: '#f3f0ef'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#ffdadb'
  secondary-fixed-dim: '#ffb2b7'
  on-secondary-fixed: '#40000d'
  on-secondary-fixed-variant: '#92002a'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Newsreader
    fontSize: 40px
    fontWeight: '600'
    lineHeight: 48px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Newsreader
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Newsreader
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-sm:
    fontFamily: Manrope
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  mono-label:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 14px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  margin-mobile: 24px
  gutter-mobile: 16px
  stack-xs: 4px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
  stack-xl: 48px
---

## Brand & Style
The design system for this India-focused AI audio companion is built on a **Modern Editorial** aesthetic. It prioritizes clarity and utility for users navigating high-density urban environments. The style is characterized by high-contrast legibility, generous whitespace, and a sophisticated mix of systematic sans-serifs with authoritative serifs.

The interface avoids "app-like" clutter, instead feeling like a premium digital publication that talks back. It maintains a calm, intelligent, and focused tone, ensuring that the AI’s audio presence is matched by a visual environment that reduces cognitive load during transit.

## Colors
The palette is rooted in a crisp, high-contrast foundation to ensure outdoor readability under bright sunlight.

- **Background (#FAFAFA):** A bright off-white that feels cleaner and more premium than pure white, providing a paper-like quality for the editorial style.
- **Primary Cobalt (#2563EB):** Used for primary actions, active states, and navigation cues. It represents reliability and technology.
- **Secondary Coral (#F43F5E):** A warm, energetic accent used sparingly for progress indicators, live recording states, and critical highlights.
- **Charcoal Surface (#2D2D2D):** Used for dark-mode-style components within the light theme, such as bottom sheets or persistent audio players, to create strong visual separation.
- **Text (#1A1A1A):** Near-black for maximum accessibility and a sharp, ink-on-paper feel.

## Typography
This design system employs a dual-typeface strategy to reinforce the "Audio Editorial" narrative.

- **Newsreader** is the voice of the AI. It is used for large headlines, pull quotes, and narrative summaries. It brings a literary, authoritative quality to the experience.
- **Manrope** is the functional workhorse. It is used for all interface elements, metadata, and body text. Its modern, geometric construction ensures legibility at small sizes during movement.

Use **Display-LG** for primary screen headers and **Label-SM** (all-caps) for category tags or small metadata like "LIVE" or "ETA".

## Layout & Spacing
The layout follows a **Mobile-First 4-Column Grid**. Given the context of use (India transit/walking), margins are intentionally generous (24px) to prevent accidental edge-touches and to frame content elegantly.

- **Vertical Rhythm:** Use a 4px baseline grid. Elements should be stacked using the `stack` variables to maintain consistent grouping.
- **Touch Targets:** Minimum 48x48px for all interactive elements, regardless of visual size.
- **Safe Areas:** Ensure content respects bottom-bar home indicators on modern mobile devices, especially for the persistent audio player.

## Elevation & Depth
In line with the Modern Editorial style, this system avoids traditional drop shadows and skeuomorphism. Depth is communicated through **Tonal Layering and Border Definition**.

- **Level 0 (Base):** The #FAFAFA background.
- **Level 1 (Cards):** Defined by a 1px solid border (#E5E5E5) rather than a shadow. This keeps the UI feeling flat and architectural.
- **Level 2 (Overlays/Bottom Sheets):** These use the Charcoal (#2D2D2D) surface to create a "night mode" contrast against the light background, signaling a change in context (e.g., active listening mode).
- **Focus States:** High-visibility 2px Cobalt (#2563EB) outlines for accessibility.

## Shapes
The shape language is disciplined and geometric. A standard **8px (0.5rem)** corner radius is applied to cards, input fields, and primary buttons. 

- **Interactive Elements:** Buttons and form fields use the standard 8px radius.
- **System Tags:** Small labels and chips may use a fully rounded (pill) shape to distinguish them from actionable buttons.
- **Icons:** Use 2px stroke-based icons with slightly rounded caps to match the font geometry. Avoid filled icons unless they represent an active toggle state.

## Components

### Buttons
- **Primary:** Cobalt (#2563EB) background, white text, 8px radius. Heavyweight Manrope.
- **Secondary:** Transparent background, 1px #1A1A1A border, #1A1A1A text.
- **Audio Control:** Large, circular buttons with stroke-based icons. The "Play/Pause" should be the most prominent element on transport screens.

### Cards
- Minimalist style. White background, 1px #E5E5E5 border, 8px radius. 
- No shadows. Padding should be 20px or 24px to match global margins.

### Progress & Audio Visualizers
- **Seek Bars:** Use a thin #E5E5E5 track with a Coral (#F43F5E) fill. 
- **AI Listening State:** A simple, pulsing Coral dot or a minimal waveform stroke. Avoid complex 3D animations.

### Inputs
- Underlined or subtly bordered (1px). Focus state shifts the border to Cobalt. 
- Use Manrope for input text to ensure clarity in addresses and numbers.

### List Items
- Clean dividers (1px #F0F0F0). 
- High-contrast typography hierarchy: Newsreader for the title, Manrope for the supporting metadata.