# NoteWall - Complete Product & Technical Context

## 1. The Hard Paywall Implementation

NoteWall currently implements a **Hard Paywall** strategy designed to maximize conversion by restricting core functionality until a subscription is active.

### Core Logic
- **Free Export Limit**: **0** (Zero).
  - *Note*: While some business documentation mentions "3 free exports", the current codebase (`PaywallManager.swift`) explicitly sets `private let freeExportLimit = 0`.
  - This means users **cannot export any wallpapers** without a subscription.
- **Trigger Timing**:
  - The paywall is checked immediately upon app launch if the user has completed setup.
  - If `hasCompletedSetup` is true and the user is not premium, the paywall is triggered.
  - The paywall is also triggered whenever a user attempts to export a wallpaper (`trackWallpaperExport`).

### Paywall Triggers
The app tracks specific reasons for showing the paywall (`PaywallTriggerReason`):
1. **Limit Reached**: Triggered when the user attempts to export a wallpaper and has 0 remaining free exports (which is always true for free users).
2. **First Wallpaper Created**: (Legacy/Optional) Triggered after the first creation.
3. **Manual**: User taps the "Upgrade" or "Pro" button in settings.
4. **Exit Intercept**: Triggered when the user attempts to leave the app or close a flow (often offers a discount).
5. **Settings**: Accessed via the settings menu.

### Superwall Integration
NoteWall uses **Superwall** for paywall UI and experimentation.
- **Wrapper**: `SuperwallPaywallView` wraps the Superwall SDK's `PaywallView`.
- **User Attributes**: The app sends comprehensive user data to Superwall for segmentation and targeting (`SuperwallUserAttributesManager.swift`):
  - **Subscription Status**: `isPremium`, `hasLifetimeAccess`, `subscriptionExpiryDate`, `isInTrial`.
  - **Usage Stats**: `wallpaperExportCount`, `remainingFreeExports`, `hasReachedFreeLimit`.
  - **Onboarding**: `hasCompletedSetup`, `daysSinceInstall`, `completedOnboardingVersion`.
  - **Content**: `noteCount`, `completedNoteCount`, `hasNotes`.
  - **Preferences**: `hasLockScreenWidgets`, `lockScreenBackground` type.

### Monetization (RevenueCat)
- **Entitlement ID**: "Notewall+"
- **Products**:
  - **Monthly Subscription**: Recurring revenue.
  - **Lifetime Access**: One-time purchase (often used for exit intercepts with a discount).
  - **Annual Subscription**: (If configured in RevenueCat).
- **Trial Logic**:
  - The app tracks `trialStartDate`.
  - A "Trial Ending Soon" reminder is shown between 24h and 72h after trial start.

---

## 2. What is NoteWall?

**NoteWall** is an iOS productivity application that transforms the iPhone lock screen into a personalized, unavoidable reminder system.

### Core Value Proposition
> "You forget things for one simple reason: you don't see them. NoteWall fixes that."

- **The Problem**: "Out of sight, out of mind." Important goals and tasks hidden in apps are easily ignored.
- **The Solution**: NoteWall overlays your notes directly onto your lock screen wallpaper.
- **The Mechanism**: Every time you pick up your phone (avg. 498 times/day), you see your goals *before* you get distracted by social media.

### Target Audience
1. **Goal-Oriented Individuals**: Fitness enthusiasts, students, professionals tracking daily objectives.
2. **Productivity Seekers**: People trying to reduce screen time and phone addiction.
3. **Visual Learners**: Users who need constant visual cues to stay on track.
4. **The "Forgetful"**: People who need reminders that cannot be swiped away.

### Key Features
- **Lock Screen Notes**: Notes are "baked" into the wallpaper image.
- **Smart Styling**: Adaptive text sizing (52-140pt) and auto-color (black/white) based on background brightness.
- **Widget Awareness**: Automatically adjusts note position if lock screen widgets are present.
- **Automation**: Integrates with **Apple Shortcuts** to automatically update the wallpaper whenever notes are changed in the app.
- **Privacy**: All data is stored locally on the device.

---

## 3. Technical Architecture

### Stack
- **Platform**: iOS 15.0+ (Native Swift/SwiftUI).
- **Backend**: None (Local storage).
- **Analytics**: Firebase Analytics (GA4) + TelemetryDeck.
- **Paywall/Revenue**: Superwall + RevenueCat.
- **Automation**: Apple Shortcuts (Critical dependency).

### The "Shortcuts" Limitation & Workaround
Apple's Shortcuts app has a limitation where it cannot programmatically set "Preset" wallpapers (e.g., Astronomy, Emoji, Gradients). It only works with **Photo-based** wallpapers.

**The Fix (Onboarding Flow)**:
1. The app detects if the user might be using a preset.
2. It provides a "Red Instruction Image" that says "SET THIS AS YOUR WALLPAPER".
3. The user must manually set this image as their lock screen wallpaper from the Photos app.
4. Once set, the Shortcut can successfully "replace" this photo with the generated NoteWall wallpaper.

### Data Flow
1. **User Input**: User adds notes in the app.
2. **Generation**: `WallpaperRenderer` creates a `UIImage` with text overlays.
3. **Storage**: Image is saved to the app's shared App Group container.
4. **Trigger**: App runs the "NoteWall" Shortcut.
5. **Execution**: Shortcut reads the image from the shared container and calls the system "Set Wallpaper" action.

---

## 4. Onboarding Flow (The "Funnel")

The app features a high-conversion, 6-step onboarding flow:

1. **Pre-Onboarding Hook**: Animated intro ("You forget things...").
2. **Welcome**: Value prop ("Turn Every Pickup Into Focus").
3. **Video Introduction**: Explains the Shortcuts limitation (Video + Text toggle).
4. **Install Shortcut**: Deep link to iCloud to install the required Shortcut.
   - *Troubleshooting*: "How-to-Fix" guide if installation fails.
5. **Add Notes**: User creates their first set of notes.
6. **Choose Wallpapers**: User picks a background (Photo or Color).
7. **Allow Permissions**: 3 Critical Permissions required:
   - Shortcuts Folder Access (Home Screen).
   - Shortcuts Folder Access (Lock Screen).
   - Notifications (for update alerts).
8. **Overview**: Final "You're All Set" celebration.

---

## 5. Recent Updates & Analytics

### New "What's New" View
A new post-update popup (`WhatsNewView.swift`) has been added to engage existing users:
- **Triggers**: Shows only to existing users after an app update.
- **Content**: Highlights "Performance Boost", "Bug Fixes", and "UI Polish".
- **Call to Action**: Encourages users to rate the app on the App Store.
- **Design**: Matches the dark, premium aesthetic of the onboarding flow.

### Analytics Dashboard (`notewall-analytics-dashboard`)
A dedicated Next.js web dashboard has been built to track business health.

**Key Metrics Tracked**:
- **Onboarding Funnel**: Drop-off rates across all 18 steps.
- **Paywall Performance**: Impressions, Conversion Rate, Revenue, ARPU.
- **User Engagement**: Daily Active Users (DAU), Sessions.
- **Technical Stats**: Wallpaper export counts, Permission acceptance rates.
- **Demographics**: Device models, Country breakdown.

**Tech Stack**:
- **Frontend**: Next.js 14, Tailwind CSS, Recharts.
- **Backend**: Firebase Admin SDK (fetching data from Google Analytics 4).
- **Deployment**: Vercel.

---

## 6. User Personas

- **"The Goal Achiever"**: 25-45yo. Sets daily goals but forgets them. Needs constant reinforcement.
- **"The Distracted Professional"**: 28-50yo. Picks up phone for work, gets lost in Instagram. Needs a "stop sign" on the lock screen.
- **"The Habit Builder"**: 20-40yo. Trying to drink more water, read more, etc. Needs visual cues.
