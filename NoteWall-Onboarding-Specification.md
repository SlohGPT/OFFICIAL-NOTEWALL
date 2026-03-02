# NoteWall Onboarding Flow — Complete Specification

> **Purpose**: This document contains every design detail, exact color value, font size, animation timing, and SwiftUI code needed to recreate the NoteWall onboarding flow pixel-perfect. Hand this to any AI model or developer as a standalone reference.

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Flow Overview (24 Pages)](#2-flow-overview)
3. [Phase 0: Pre-Onboarding](#3-phase-0-pre-onboarding)
4. [Phase 1: Emotional Hook & Quiz](#4-phase-1-emotional-hook--quiz)
5. [Phase 2: Social Proof — Trajectory Graph](#5-phase-2-social-proof--trajectory-graph)
6. [Phase 2.5: Notification Permission](#6-phase-25-notification-permission)
7. [Phase 3: Technical Setup](#7-phase-3-technical-setup)
8. [Phase 4: Celebration & Completion](#8-phase-4-celebration--completion)
9. [Shared Components](#9-shared-components)
10. [Animation Patterns Reference](#10-animation-patterns-reference)

---

## 1. Design System

### 1.1 Colors

| Token | Value | CSS/Hex | Usage |
|-------|-------|---------|-------|
| `AppAccent` (light) | `sRGB(0.000, 0.768, 0.722)` | `#00C4B8` | Primary accent, buttons, highlights |
| `AppAccent` (dark) | `sRGB(0.000, 0.768, 0.722)` | `#00C4B8` | Same in both modes |
| Background gradient top | `rgb(0.03-0.05, 0.03-0.05, 0.07-0.10)` | `#080814` – `#0D0D1A` | Dark gradient start |
| Background gradient bottom | `rgb(0, 0, 0)` | `#000000` | Pure black |
| Red (forgetting curve) | `rgb(1.0, 0.2, 0.2)` | `#FF3333` | Danger/negative |
| White primary text | `#FFFFFF` at `0.9` opacity | — | Main body text |
| White secondary text | `#FFFFFF` at `0.5-0.7` opacity | — | Subtitles, descriptions |
| White tertiary text | `#FFFFFF` at `0.3-0.4` opacity | — | Labels, hints |
| Glass card fill | `#FFFFFF` at `0.03-0.05` opacity | — | Card backgrounds |
| Glass card border | `#FFFFFF` at `0.08-0.1` opacity | — | Subtle borders |

### 1.2 Typography

All fonts use **SF Pro** (system font). Specific design tokens:

| Style | Font | Size (compact / regular) | Weight | Design |
|-------|------|--------------------------|--------|--------|
| Hero Title | System | 28pt / 36pt | `.bold` | `.rounded` |
| Section Title | System | 22pt / 28pt | `.bold` | `.rounded` |
| Body Large | System | 15pt / 17pt | `.medium` | `.default` |
| Body | System | 14pt / 16pt | `.medium` | `.default` |
| Caption | System | 12pt / 14pt | `.medium` | `.default` |
| Tiny Label | System | 11pt / 13pt | `.medium` | `.default` |
| Big Stat Number | System | 72pt / 96pt | `.black` | `.rounded` |
| Button Text | System | 15pt / 17pt | `.semibold` | `.default` |

### 1.3 Compact Device Detection

```swift
private var isCompact: Bool { ScreenDimensions.isCompactDevice }
// isCompactDevice = screen height < ~750pt (e.g. iPhone SE, iPhone 8)
```

All sizes in this doc are listed as `compact / regular`.

### 1.4 Adaptive Layout Constants

```swift
struct AdaptiveLayout {
    static var horizontalPadding: CGFloat {
        ScreenDimensions.isCompactDevice ? 20 : 24
    }
}
```

### 1.5 Background Pattern (used on EVERY page)

```swift
LinearGradient(
    colors: [Color(red: 0.03, green: 0.03, blue: 0.07), Color.black],
    // OR slightly brighter variant:
    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
    startPoint: .top,
    endPoint: .bottom
)
.ignoresSafeArea()

// Optional: Radial accent glow overlay
RadialGradient(
    colors: [Color.appAccent.opacity(0.08), Color.clear],
    center: .top, // or .center
    startRadius: 0,
    endRadius: 400
)
```

### 1.6 Glass Card Style

```swift
RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
    .fill(Color.white.opacity(0.04))
    .overlay(
        RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
```

### 1.7 Primary Button Style

```swift
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .white : .white.opacity(0.4))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isEnabled
                            ? LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
            )
            .shadow(color: isEnabled ? Color.appAccent.opacity(0.25) : .clear, radius: 16, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isEnabled ? Color.white.opacity(0.15) : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
    }
}
```

### 1.8 Badge / Capsule Component

```swift
HStack(spacing: 6) {
    Image(systemName: "sparkles")
        .font(.system(size: isCompact ? 12 : 14))
        .foregroundColor(.appAccent)
    Text("Label")
        .font(.system(size: isCompact ? 12 : 13, weight: .medium))
        .foregroundColor(.appAccent)
}
.padding(.horizontal, isCompact ? 12 : 16)
.padding(.vertical, isCompact ? 6 : 8)
.background(
    Capsule()
        .fill(Color.appAccent.opacity(0.1))
        .overlay(
            Capsule()
                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
        )
)
```

---

## 2. Flow Overview

The onboarding has **24 pages** (enum `OnboardingPage`), split into 5 phases:

```
Phase 0: Pre-Onboarding
  1. preOnboardingHook   — Animated phone mockup with sticky notes flying in
  2. nameInput           — "What should we call you?" with keyboard auto-focus

Phase 1: Emotional Hook & Quiz
  3. painPoint           — "498 phone unlocks/day" stat reveal + "remember why?" question
  4. quizForgetMost      — Multi-select: "What do you forget the most?"
  5. quizPhoneChecks     — Single-select: "How often do you check your phone?"
  6. quizDistraction     — Multi-select: "What distracts you most?"
  7. personalizationLoading — Fake loading screen "Curating Your Experience"
  8. resultsPreview      — "Your Focus Profile" card with personalized insights
  9. resultsInsight      — Lightbulb moment: "What this means" with typewriter text

Phase 2: Social Proof & Value
  10. socialProof         — ★★★ TRAJECTORY GRAPH ★★★ (see Section 5)

Phase 2.5: Notification Permission
  11. notificationPermission — Mock notification cards + "Keep Me in the Loop" CTA

Phase 3: Technical Setup
  12. setupIntro          — "Quick 4-Minute Setup" with numbered step preview
  13. welcome             — Video introduction / demo
  14. installShortcut     — iOS Shortcut installation with PiP video guide
  15. shortcutSuccess     — 🎉 "Nailed It!" celebration
  16. addNotes            — User adds their first notes
  17. chooseWallpapers    — Wallpaper style picker
  18. allowPermissions    — Notification permissions + video

Phase 4: Celebration & Completion
  19. setupComplete       — "Your Focus System Is Ready!" with stats card
  20. overview            — Mockup preview of the final wallpaper
  21. reviewPage          — "Rate us" / final review → triggers paywall
```

**Transitions between pages:**
- `.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))`
- Animation: `.easeInOut(duration: 0.25)`

**Color scheme:** `.preferredColorScheme(.dark)` — always dark mode

---

## 3. Phase 0: Pre-Onboarding

### 3.1 Pre-Onboarding Hook (`preOnboardingHook`)

**Concept:** Animated sticky notes fly onto a phone mockup from alternating directions, creating a visual demo of what NoteWall does.

**Animation States:**
```swift
@State var firstNoteXOffset: CGFloat = -300     // Start off-screen left
@State var firstNoteRotation: Double = -15       // Start rotated
@State var firstNoteOpacity: Double = 0
@State var firstNoteScale: CGFloat = 0.8

// 3 additional notes alternate directions:
@State var notesXOffset: [CGFloat] = [300, -300, 300]  // right, left, right
@State var notesRotation: [Double] = [15, -15, 15]
@State var notesOpacity: [Double] = [0, 0, 0]
@State var notesScale: [CGFloat] = [0.8, 0.8, 0.8]

@State var mockupOpacity: Double = 0
@State var mockupScale: CGFloat = 0.95
@State var overallOffset: CGFloat = 100  // Starts lower, slides up
```

**Animation Sequence:** Notes fly in one by one with spring animations, landing on the mockup. After all notes land, the continue button fades in.

### 3.2 Name Input (`nameInput`)

**View:** `NameInputView`

**Layout:**
- 👋 hand wave emoji: `48pt / 60pt`, bounces in with spring, wiggles 3x
- Subtitle: "First things first" — `14pt / 16pt`, `.medium`, white @ 0.5 opacity
- Title: "What should we\ncall you?" — `28pt / 34pt`, `.bold`, `.rounded`, white
- Text field with glow border, person icon, checkmark when valid
- Continue button

**Text Field Design:**
```swift
// Outer container
padding: 16pt / 20pt horizontal, 14pt / 18pt vertical
cornerRadius: 16pt / 18pt

// Background
Color.white.opacity(0.07)

// Border when focused
LinearGradient(
    colors: [Color.appAccent.opacity(0.6), Color.appAccent.opacity(0.2)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
lineWidth: focused ? 1.5 : 1

// Person icon circle
Circle fill: isValid ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.04)
Icon color: isValid ? .appAccent : .white.opacity(0.25)
```

**Post-Submit Greeting:**
- Fades to: "Nice to meet you," + "{Name}!" with animated gradient
- Name gradient: `[.appAccent, .appAccent.opacity(0.7), Color(red: 0.4, green: 0.7, blue: 1.0), .appAccent]`
- Subtitle: "Let's make forgetting a thing of the past"
- Auto-advances after 2.2 seconds

**Animation Sequence:**
```
0.05s  — 👋 emoji: spring(0.45, 0.55)
0.1s   — Subtitle: easeOut(0.4)
0.15s  — Title: easeOut(0.4)
0.25s  — Field: spring(0.45, 0.8)
0.3s   — Auto-focus keyboard
0.35s  — Button: easeOut(0.4)
0.4s   — Emoji wave wiggle: 3x, easeInOut(0.15)
```

---

## 4. Phase 1: Emotional Hook & Quiz

### 4.1 Pain Point (`painPoint`)

**View:** `PainPointView` — 2 internal steps

#### Step 0: Stats Reveal

**Layout (top to bottom):**
1. Badge: "Research Insight" with chart icon — capsule style
2. Personalized text: "Hey {name}, did you know that" — `16pt / 19pt`, `.medium`, white @ 0.7
3. "the average person unlocks their phone up to" — same style
4. **Big animated number** "498" — `72pt / 96pt`, `.black`, `.rounded`
   - Gradient: `[.appAccent, .appAccent.opacity(0.7)]`
   - Shadow: `appAccent.opacity(0.4), radius: 20, y: 10`
   - Uses `CountingText` modifier that animates from 0→498
5. "times per day ?" — `14pt / 17pt`, `.semibold`, white @ 0.6
6. Three stat mini cards in a row:

**Stat Mini Cards:**
```swift
// Each card
VStack(spacing: 6/8pt)
    Icon: 14pt/16pt, white @ 0.4
    Value: 18pt/22pt, .bold, .rounded, white
    Label: 10pt/11pt, white @ 0.4

Background: RoundedRectangle(12/14pt), white.opacity(0.04)
Padding: 12/16pt vertical

// Values:
Card 1: icon "clock.fill",    value "4hrs",  label "screen time"
Card 2: icon "brain.head.profile", value "96%", label "forgotten"
Card 3: icon "eye.fill",      value "2.5s",  label "avg glance"
```

**Button:** "Tell Me More →"

**Animation Sequence:**
```
0.1s  — Header badge: easeOut(0.6)
0.3s  — Text 1 & 2: easeOut(0.6)
0.5s  — Number: spring(0.6, 0.7) + number count animation easeOut(1.5)
1.2s  — Card 1: easeOut(0.5)
1.4s  — Card 2: easeOut(0.5)
1.6s  — Card 3: easeOut(0.5)
2.0s  — Button: easeOut(0.5)
After number lands — Heavy haptic
```

#### Step 1: The Question

**Transition:** `withAnimation(.easeInOut(duration: 0.4))`

**Layout:**
1. Typewriter text: "But here's the real question..." — `16pt / 18pt`, `.medium`, white @ 0.5
   - Typing speed: 0.06s per character
   - Light haptic every 4th character
2. Three lines fade in sequentially:
   - "How many times" — `28pt / 36pt`, `.bold`, `.rounded`, white
   - "did you actually" — same
   - "remember **why?**" — "why?" in `.appAccent`

**Staggered line reveal (after typewriter finishes):**
```
+0.4s  — Line 1: easeOut(0.8)
+1.4s  — Line 2: easeOut(0.8)
+2.4s  — Line 3: easeOut(0.8)
+3.4s  — Button: easeOut(0.6)
```

### 4.2 Quiz Questions

#### `quizForgetMost` — Multi-Select

**Question:** "What do you forget the most?"
**Subtitle:** "Select all that apply"
**Options:** Emoji + text, multi-select with checkmark indicator

#### `quizPhoneChecks` — Single-Select

**Question:** "How often do you check your phone?"
**Options:** Single-select, auto-advances after 0.4s delay

#### `quizDistraction` — Multi-Select

**Question:** "What distracts you most?"
**Options:** Multi-select with Continue button

**Quiz Option Button Design:**
```swift
HStack(spacing: 12/16pt)
    Emoji: 24pt/28pt
    Title: 15pt/17pt, .medium, white
    Spacer
    Checkmark (if selected): "checkmark.circle.fill" 20pt/24pt, appAccent

Background:
    Selected: appAccent.opacity(0.2), border: appAccent, lineWidth: 2
    Unselected: white.opacity(0.05), border: white.opacity(0.1), lineWidth: 1
Corner radius: 14pt/16pt
Padding: 16pt/20pt H, 12pt/16pt V
```

### 4.3 Personalization Loading (`personalizationLoading`)

**View:** `PersonalizationLoadingView`

**Duration:** 3.5 seconds total

**Layout:**
1. Pulsing glow circle (RadialGradient, appAccent @ 0.3, alternating scale 0.9↔1.1)
2. Rotating ring (trim 0→0.7, appAccent gradient, lineWidth: 3, rotates 2x during progress)
3. Center icon: "sparkles" in circle, `32pt / 40pt`
4. Title: "Curating Your Experience" — `22pt / 28pt`, `.bold`, `.rounded`
5. Subtitle: "Just for you" — `14pt / 16pt`, `.medium`, appAccent
6. Cycling messages (crossfade): "Analyzing your habits..." → "Customizing..." → "Preparing..." → "Almost ready..."
7. Progress bar with percentage (`0%→100%`)
   - 0-89%: Quick (0.015-0.035s per %)
   - 90-94%: Normal (0.04s)
   - 95-100%: Slower (0.08-0.12s)
8. Success haptic at completion → auto-advance

### 4.4 Results Preview (`resultsPreview`)

**View:** `ResultsPreviewView`

**Layout:**
1. Badge: "✓ Analysis Complete" — appAccent, capsule with spring-in
2. Title: "{Name}'s Focus Profile" — `28pt / 36pt`, `.bold`, `.rounded`
3. Profile card (glass card):
   - Header: Brain icon + "Based on your answers / Here's what we learned"
   - "YOU WANT TO REMEMBER" — user's quiz answers in accent capsules
   - "YOUR BIGGEST CHALLENGE" — distraction answer
   - "DAILY PHONE CHECKS" — count + 5-bar intensity indicator
4. Button: "See Insights →"

**Animation:**
```
0.2s — Badge: spring(0.5, 0.6)
0.3s — Header: easeOut(0.6)
0.6s — Profile card: spring(0.6, 0.75), slides up from +40pt
1.0s — Button: easeOut(0.6)
0.3s — Success haptic
```

### 4.5 Results Insight (`resultsInsight`)

**View:** `ResultsInsightView`

**Layout:**
1. Lightbulb icon: `lightbulb` / `lightbulb.fill` — `60pt / 72pt`
   - Glow circle: yellow @ 0.3, 120x120pt, blur 20
   - Shadow: yellow @ 0.8, radius 10
2. Typewriter title: "What this means" — `18pt / 22pt`, `.semibold`, white @ 0.6
3. Three big insight text rows — `22pt / 26pt`, `.medium`, white @ 0.9:
   - "You check your phone\n{frequency}" — frequency in appAccent
   - "That's {count} daily chances to remember what matters."
   - "...instead of losing time to {distraction}." — `.semibold`, white
4. Button: "Let's Set It Up →"

**Animation Sequence:**
```
0.0s   — Lightbulb: spring(0.8, 0.7) scale 0.5→1.0
0.8s   — Lightbulb lights up: easeOut(0.6) + medium haptic
1.5s   — Typewriter title starts (0.05s/char)
2.5s   — Row 1: easeIn(1.5) — slow read timing
5.0s   — Row 2: easeIn(1.5)
7.5s   — Row 3: easeIn(1.5)
9.0s   — Button: easeOut(1.0)
```

---

## 5. Phase 2: Social Proof — Trajectory Graph ★

> **This is the graph view similar to the "Reset" app screenshot. Aliased: `SocialProofView = TrajectoryView`**

### 5.1 View: `TrajectoryView`

**Complete SwiftUI code:**

```swift
struct TrajectoryView: View {
    let onContinue: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var graphOpacity: Double = 0
    @State private var upwardCurveTrim: CGFloat = 0
    @State private var downwardCurveTrim: CGFloat = 0
    @State private var labelsOpacity: Double = 0
    @State private var bottomTextOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    private var isCompact: Bool { ScreenDimensions.isCompactDevice }

    var body: some View {
        ZStack {
            // -- BACKGROUND --
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 30 : 50)

                        // -- TITLE --
                        Text("Your New Trajectory")
                            .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(titleOpacity)
                            .padding(.horizontal, 24)

                        Spacer(minLength: isCompact ? 12 : 16)

                        // -- SUBTITLE with accent --
                        (Text("Never forget ") + Text("what matters").foregroundColor(.appAccent))
                            .font(.system(size: isCompact ? 16 : 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(subtitleOpacity)
                            .padding(.horizontal, 24)

                        Spacer(minLength: isCompact ? 24 : 36)

                        // -- GRAPH CONTAINER --
                        VStack(spacing: 0) {
                            ZStack {
                                // Graph background card
                                RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                    )

                                VStack(spacing: 0) {
                                    // Curves area
                                    GeometryReader { geometry in
                                        ZStack {
                                            // RED downward curve (Forgetting)
                                            DownwardCurveShape()
                                                .trim(from: 0, to: downwardCurveTrim)
                                                .stroke(
                                                    Color(red: 1.0, green: 0.2, blue: 0.2),
                                                    style: StrokeStyle(lineWidth: isCompact ? 3 : 4, lineCap: .round)
                                                )
                                                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.6), radius: 12)

                                            // ACCENT upward curve (NoteWall)
                                            UpwardCurveShape()
                                                .trim(from: 0, to: upwardCurveTrim)
                                                .stroke(
                                                    Color.appAccent,
                                                    style: StrokeStyle(lineWidth: isCompact ? 3 : 4, lineCap: .round)
                                                )
                                                .shadow(color: Color.appAccent.opacity(0.6), radius: 12)
                                                .shadow(color: Color.appAccent.opacity(0.3), radius: 20)

                                            // Labels
                                            VStack {
                                                HStack {
                                                    // NoteWall label (top-left)
                                                    HStack(spacing: 6) {
                                                        Circle()
                                                            .fill(Color.appAccent)
                                                            .frame(width: isCompact ? 8 : 10, height: isCompact ? 8 : 10)
                                                            .shadow(color: Color.appAccent.opacity(0.8), radius: 4)
                                                        Text("NoteWall")
                                                            .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                                                            .foregroundColor(.appAccent)
                                                    }
                                                    .padding(.horizontal, isCompact ? 10 : 12)
                                                    .padding(.vertical, isCompact ? 5 : 6)
                                                    .background(Capsule().fill(Color.appAccent.opacity(0.15)))
                                                    .opacity(labelsOpacity)
                                                    Spacer()
                                                }
                                                .padding(.top, isCompact ? 12 : 16)
                                                .padding(.leading, isCompact ? 16 : 20)

                                                Spacer()

                                                // Forgetting label (bottom-right)
                                                HStack {
                                                    Spacer()
                                                    HStack(spacing: 6) {
                                                        Circle()
                                                            .fill(Color(red: 1.0, green: 0.2, blue: 0.2))
                                                            .frame(width: isCompact ? 8 : 10, height: isCompact ? 8 : 10)
                                                            .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.8), radius: 4)
                                                        Text("Forgetting")
                                                            .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                                                            .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))
                                                    }
                                                    .padding(.horizontal, isCompact ? 10 : 12)
                                                    .padding(.vertical, isCompact ? 5 : 6)
                                                    .background(Capsule().fill(Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.15)))
                                                    .opacity(labelsOpacity)
                                                }
                                                .padding(.bottom, isCompact ? 30 : 40)
                                                .padding(.trailing, isCompact ? 16 : 20)
                                            }
                                        }
                                    }
                                    .frame(height: isCompact ? 180 : 220)
                                    .padding(.horizontal, isCompact ? 12 : 16)
                                    .padding(.top, isCompact ? 16 : 20)

                                    // X-axis labels
                                    HStack {
                                        Text("Now")
                                        Spacer()
                                        Text("Daily")
                                        Spacer()
                                        Text("Always")
                                    }
                                    .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, isCompact ? 24 : 32)
                                    .padding(.bottom, isCompact ? 16 : 20)
                                    .opacity(labelsOpacity)
                                }
                            }
                            .frame(height: isCompact ? 240 : 300)
                        }
                        .opacity(graphOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)

                        Spacer(minLength: isCompact ? 24 : 36)

                        // -- BOTTOM MESSAGE --
                        VStack(spacing: isCompact ? 8 : 12) {
                            Text("Never forget what matters.")
                                .font(.system(size: isCompact ? 20 : 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("NoteWall puts your most important things on your wallpaper, so you see them every time you unlock your phone.")
                                .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        .opacity(bottomTextOpacity)

                        Spacer(minLength: isCompact ? 20 : 30)
                    }
                    .padding(.bottom, isCompact ? 90 : 110)
                }

                // BUTTON
                VStack(spacing: isCompact ? 6 : 10) {
                    Button(action: { onContinue() }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text("Let's Set It Up")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        }
                        .frame(height: isCompact ? 48 : 56)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))

                    Text("Takes about 4 minutes")
                        .font(.system(size: isCompact ? 11 : 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.top, isCompact ? 10 : 14)
                .padding(.bottom, isCompact ? 16 : 22)
                .background(/* fade-to-black gradient at top */)
                .opacity(buttonOpacity)
            }
        }
    }
}
```

### 5.2 Curve Shape Definitions (EXACT bezier control points)

```swift
// ── UPWARD CURVE (NoteWall path — goes UP from bottom-left to top-right) ──
private struct UpwardCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let startPoint = CGPoint(x: rect.minX + 20, y: rect.maxY - 30)
        let endPoint   = CGPoint(x: rect.maxX - 20, y: rect.minY + 30)

        let control1 = CGPoint(x: rect.width * 0.3, y: rect.maxY - 20)
        let control2 = CGPoint(x: rect.width * 0.6, y: rect.minY + 50)

        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)

        return path
    }
}

// ── DOWNWARD CURVE (Forgetting — starts same spot, curves down-right, flattens) ──
private struct DownwardCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let startPoint = CGPoint(x: rect.minX + 20, y: rect.maxY - 30)
        let endPoint   = CGPoint(x: rect.maxX - 20, y: rect.maxY - 10)

        let control1 = CGPoint(x: rect.width * 0.35, y: rect.height * 0.4)
        let control2 = CGPoint(x: rect.width * 0.65, y: rect.maxY - 5)

        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)

        return path
    }
}
```

### 5.3 Graph Visual Details

| Element | Value |
|---------|-------|
| Graph container height | `240pt / 300pt` |
| Curves area height | `180pt / 220pt` |
| Container corner radius | `20pt / 24pt` |
| Container fill | `white.opacity(0.03)` |
| Container border | `white.opacity(0.08)`, 1pt |
| Upward curve color | `Color.appAccent` (#00C4B8) |
| Upward curve width | `3pt / 4pt` |
| Upward curve shadow | `appAccent.opacity(0.6)`, radius 12 + `appAccent.opacity(0.3)`, radius 20 |
| Downward curve color | `Color(red: 1.0, green: 0.2, blue: 0.2)` (#FF3333) |
| Downward curve width | `3pt / 4pt` |
| Downward curve shadow | `#FF3333 opacity(0.6)`, radius 12 |
| Label dot size | `8pt / 10pt` |
| Label font | `12pt / 14pt`, `.semibold` |
| NoteWall label background | Capsule, `appAccent.opacity(0.15)` |
| Forgetting label background | Capsule, `red.opacity(0.15)` |
| X-axis labels | "Now", "Daily", "Always" — `11pt / 13pt`, `.medium`, white @ 0.5 |

### 5.4 Graph Animation Sequence

```
0.3s  — Title fades in: easeOut(0.6)
0.6s  — Subtitle fades in: easeOut(0.6)
0.9s  — Graph container fades in: easeOut(0.5)
1.2s  — Upward curve draws: easeInOut(1.5), trim 0→1
1.4s  — Downward curve draws: easeInOut(1.5), trim 0→1
2.5s  — Labels appear: easeOut(0.5)
2.8s  — Bottom text fades in: easeOut(0.6)
3.2s  — Button appears: easeOut(0.5)
```

**Key detail:** Both curves start from the SAME point (bottom-left). The upward curve rises to top-right, the downward curve initially rises slightly then descends and flattens at the bottom-right. This creates a visual "fork in the road" — use NoteWall and your trajectory goes UP; keep forgetting and it goes DOWN.

---

## 6. Phase 2.5: Notification Permission

### 6.1 View: `NotificationPermissionView`

**Layout:**
1. Three mock notification cards (stacked, staggered, with floating Y offset)
2. Title: "Don't miss a thing" — `30pt / 36pt`, `.bold`, `.rounded`
3. Subtitle: "Get helpful nudges that keep\nyour momentum going."
4. Primary button: "Keep Me in the Loop →" with shimmer
5. Skip: "Not now" — white @ 0.3

**Mock Notification Cards:**
```swift
// Each card:
HStack(spacing: 12/14pt)
    App icon: RoundedRect(10/12pt), gradient fill, SF Symbol
    VStack
        "NoteWall" — 11/12pt, .semibold, white @ 0.45
        Title — 13/14pt, .semibold, white @ 0.9
        Subtitle — 12/13pt, white @ 0.4
    Time label — 10/11pt, white @ 0.25

Background: RoundedRect(18/22pt), white.opacity(0.04), border white.opacity(0.1)
Padding: 14/16pt

// Three cards:
Card 1: icon "brain.head.profile.fill", appAccent gradient, "Time for a quick check-in", "Now"
Card 2: icon "sparkles", yellow→orange gradient, "New: Smart Wallpaper Themes", "2m ago", scale 0.96
Card 3: icon "flame.fill", orange→red gradient, "3-day streak!", "Earlier", scale 0.92
```

**Animation:**
```
0.0s   — Background glow: easeOut(1.2), scale 0.6→1.0
0.15s  — Card 1: spring(0.7, 0.75), slides up from +60
0.3s   — Card 2: spring(0.7, 0.75)
0.45s  — Card 3: spring(0.7, 0.75)
0.55s  — Light haptic when cards land
0.6s   — Title: spring(0.6, 0.8)
0.75s  — Subtitle: spring(0.6, 0.8)
0.8s   — Floating cards loop: easeInOut(3.0), Y offset 0→-6, forever
0.95s  — Button: spring(0.6, 0.75)
1.3s   — Skip: easeOut(0.4)
1.5s   — Button shimmer sweep starts (repeats every 3s)
```

---

## 7. Phase 3: Technical Setup

### 7.1 Setup Intro (`setupIntro`)

**View:** `SetupIntroView`

**Props passed:**
```swift
SetupIntroView(
    title: "Quick 4-Minute Setup",
    subtitle: "Let's get your focus system working",
    icon: "gearshape.2.fill",
    steps: QuizData.setupSteps,
    timeEstimate: "About 4 minutes",
    ctaText: "Let's Do This!"
)
```

**Layout:** Icon in circle → title → subtitle → numbered step list with connector lines → time estimate badge → CTA button

### 7.2 Welcome / Video Demo (`welcome`)

Video player with controls, shows how NoteWall works.

### 7.3 Install Shortcut (`installShortcut`)

Multi-state view for installing the iOS Shortcut. Features:
- PiP video guide
- "Did it work?" verification
- Troubleshooting flow

### 7.4 Shortcut Success (`shortcutSuccess`)

**View:** `CelebrationView`

**Props:**
```swift
CelebrationView(
    title: "🎉 Nailed It!",
    subtitle: "That was the hardest part.\nEverything else takes under 60 seconds.",
    encouragement: "You're crushing this setup!",
    nextStepPreview: "Add your first notes"
)
```

**Layout:**
1. Checkmark circle with 3 pulse rings
   - Rings: appAccent @ 0.3/0.2/0.1, lineWidth: 2, scale animation
   - Main circle: `76pt / 100pt`, appAccent gradient, shadow
   - Checkmark: `36pt / 48pt`, `.bold`, white
2. Title, subtitle, encouragement (in appAccent)
3. "Next: {step}" preview
4. Confetti overlay
5. Continue button

**Animation:**
```
0.1s — Checkmark: spring(0.5, 0.6) + confetti + success haptic
0.4s — Text: easeOut(0.5)
0.8s — Button: easeOut(0.4)
```

### 7.5 Add Notes (`addNotes`)

Text input for user's first notes. Notes are saved for the wallpaper.

### 7.6 Choose Wallpapers (`chooseWallpapers`)

Photo picker + wallpaper style selection.

### 7.7 Allow Permissions (`allowPermissions`)

Notification toggle + video explaining benefits.

---

## 8. Phase 4: Celebration & Completion

### 8.1 Setup Complete (`setupComplete`)

**View:** `SetupCompleteView`

**Layout:**
1. Animated rings (4 circles) + large checkmark circle
   - Circle: 120pt, appAccent gradient
   - Rings: 140/180/220/260pt, appAccent @ 0.3→0.09
   - Checkmark: 56pt, `.bold`, white
   - Shadow: appAccent @ 0.5, radius 30
2. Title: "{Name}, Your Focus System Is Ready! 🎉" — 28pt, `.bold`, `.rounded`
3. Subtitle: "You just did what 97% of people never do..."
4. Stats card (three columns with dividers):

```
┌─────────────────────────────────────────┐
│  {time}    │      ∞       │   Top 3%    │
│ Setup Time │ Daily Reminders│ Focus Elite │
└─────────────────────────────────────────┘
```

- Values: 28pt, `.bold`, `.rounded`, appAccent
- Labels: 11pt, `.medium`, white @ 0.5, uppercase
- Dividers: white @ 0.15, 1pt wide, 50pt tall
- Card: 20pt padding, rounded rect 20pt, white.opacity(0.05)

5. Button: "Unlock Full Potential →"

**Animation:**
```
0.2s — Checkmark: spring(0.6, 0.6) + success haptic
0.5s — Text: easeOut(0.5)
0.8s — Stats: easeOut(0.5)
1.1s — Button: easeOut(0.4)
```

### 8.2 Overview (`overview`)

Mockup preview of the final generated wallpaper on a phone frame.

### 8.3 Review Page (`reviewPage`)

Final review + triggers paywall on continue.

---

## 9. Shared Components

### 9.1 Confetti View

```swift
struct ConfettiView: View {
    @Binding var trigger: Int
    // Creates burst of colorful confetti pieces when trigger increments
    // Colors: appAccent, yellow, orange, pink, white
    // 50+ small rectangles/circles with random rotation, velocity, gravity
}
```

### 9.2 Floating Particles

Used on multiple screens. Pattern:

```swift
// 3-4 small circles
Circle()
    .fill(Color.appAccent.opacity(0.08-0.15))
    .frame(width: 3-6pt)
    .blur(radius: 0.5-2)
    .offset(y: particleY) // Animated with easeInOut, 3-5s, repeatForever
    .opacity(particleOpacity) // Pulsing 0↔0.6-0.8
```

### 9.3 Bottom Fade Gradient

Used behind fixed buttons:
```swift
.background(
    LinearGradient(
        colors: [Color.black.opacity(0), Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
    .frame(height: 40)
    .offset(y: -40)
    , alignment: .top
)
```

### 9.4 Progress Indicator

```swift
struct OnboardingProgressBar: View {
    let currentStep: Int   // e.g. 3
    let totalSteps: Int    // e.g. 7
    let phaseName: String  // e.g. "SETUP"
    let timeRemaining: String?

    // Phase name: 12pt, .semibold, appAccent, uppercase
    // Step counter: "Step 3 of 7" — 12pt, .medium, white @ 0.6
    // Progress bar: 6pt tall, rounded 4pt
    //   Background: white @ 0.1
    //   Fill: appAccent gradient, animated width
    // Time (optional): 11pt, white @ 0.4
}
```

---

## 10. Animation Patterns Reference

### 10.1 Common Easing Functions

| Pattern | SwiftUI | When Used |
|---------|---------|-----------|
| Fade in | `.easeOut(duration: 0.4-0.6)` | Text, buttons appearing |
| Slide up | `.spring(response: 0.45-0.7, dampingFraction: 0.55-0.8)` | Cards, elements entering |
| Scale in | `.spring(response: 0.5-0.8, dampingFraction: 0.6-0.7)` | Icons, badges |
| Curve draw | `.easeInOut(duration: 1.5)` | Graph curves, trim animation |
| Glow pulse | `.easeInOut(duration: 1.5-3.0).repeatForever(autoreverses: true)` | Background effects |
| Float | `.easeInOut(duration: 3.0).repeatForever(autoreverses: true)` | Notification cards |
| Shimmer | `.easeInOut(duration: 0.8)` | Button sweep effect |
| Wiggle | `.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)` | Emoji wave |

### 10.2 Haptic Feedback Pattern

| Event | Haptic Type |
|-------|-------------|
| Button tap | `UIImpactFeedbackGenerator(style: .medium)` |
| Option select | `UIImpactFeedbackGenerator(style: .light)` |
| Big number lands | `UIImpactFeedbackGenerator(style: .heavy)` |
| Success/completion | `UINotificationFeedbackGenerator().notificationOccurred(.success)` |
| Typewriter character | `UIImpactFeedbackGenerator(style: .light, intensity: 0.2)` every 4th char |

### 10.3 Stagger Timing Pattern

Most screens follow this cascading reveal pattern:
```
0.1-0.3s  — Top badge/header
0.3-0.5s  — Icon/image
0.5-0.7s  — Main title
0.7-0.9s  — Subtitle/description
0.9-1.2s  — Content cards/details
1.0-1.5s  — Button(s)
```

---

## Summary

This NoteWall onboarding is a 24-page, psychologically-crafted conversion flow that uses:

1. **Dark, premium aesthetic** — Near-black backgrounds with teal accent (#00C4B8)
2. **Glass-morphism cards** — Subtle white fills (3-5% opacity) with thin borders
3. **Cinematic animations** — Staggered reveals, spring physics, curve drawing
4. **Emotional arc** — Pain point → quiz → personalized insight → trajectory graph → value promise → celebration
5. **The trajectory graph** shows a visual fork: NoteWall users' retention curves UP (teal), while forgetting curves DOWN (red), both starting from the same point, using cubic bezier curves

Every element is designed for dark mode with `.preferredColorScheme(.dark)` enforced.
