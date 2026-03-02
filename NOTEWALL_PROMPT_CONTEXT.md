# NoteWall - Master Prompt Context

> **Purpose:** This document is designed to be pasted into an AI prompt to provide complete, up-to-date context about the NoteWall application, its purpose, its target audience, and its technical mechanics.

## 1. What is NoteWall? (The App's Purpose)
**NoteWall** is a native iOS productivity app (Swift/SwiftUI) that transforms the iPhone lock screen into an unavoidable, personalized reminder system. 

It takes the user's most important notes, tasks, or goals and "bakes" them directly into their lock screen wallpaper image. Unlike standard reminder apps that require user effort to open, NoteWall relies on **passive visibility**.

## 2. Why is it Special? (The Core Value Proposition)
- **The Problem:** "Out of sight, out of mind." Goals hidden inside apps are forgotten. When people pick up their phones, they get distracted by social media (Instagram, TikTok) before they remember what they actually needed to do.
- **The Solution:** The average person picks up their phone **498 times a day**. NoteWall places goals *on the lock screen*, hijacking those 498 pickups to serve as constant visual cues. You see your goals *before* you unlock the phone or get distracted.
- **Slogan:** *"Turn Every Pickup Into Focus / You forget things for one simple reason: you don't see them. NoteWall fixes that."*

## 3. Target Audience
- **The Goal Achiever:** Fitness tracking, studying, side-hustles.
- **The Distracted Professional:** Trying to curb screen time and doom-scrolling. 
- **The Habit Builder & The Forgetful:** Visual learners who need strict, unswipeable reminders to stay on track.

## 4. How Does It Work? (Technical Mechanics)
1. **User Input:** The user adds notes in the NoteWall app.
2. **Generation (`WallpaperRenderer.swift`):** The app generates a custom 1290x2796px `UIImage`. It takes a background (a photo from the user's library or a solid color), overlays the text, automatically scales the font (52pt-140pt), auto-adjusts text color for contrast (black vs. white text), and dynamically positions the text to avoid the iOS clock and lock screen widgets.
3. **The Automation (Apple Shortcuts):** NoteWall relies entirely on a custom **Apple Shortcut** installed onto the user's device via iCloud. 
4. **Execution:** The app saves the generated image locally. The Shortcut reads this image from the app's shared App Group container and applies it to the lock screen. Whenever notes are updated, the app triggers the shortcut to auto-update the wallpaper seamlessly.

## 5. The "Apple Limitation" & Onboarding Quirks
**Crucial Context:** Apple's Shortcuts app **cannot** programmatically apply wallpapers if the user is currently using an Apple "Preset" (e.g., default gradients, Astronomy, Emoji wallpapers). It only works on **Photo-based** wallpapers.

To bypass this limitation, NoteWall has a massive, highly optimized **6-step Onboarding Funnel**:
- **Emotional Hook & Quiz:** Animates the "498 pickups" stat, asks users about their distractions, and shows a "Trajectory Graph" (NoteWall goes UP, Forgetting goes DOWN).
- **The Video Guide:** Explicitly explains the Apple Shortcut limitation to the user.
- **The Red Image Fix:** If the user fails to install the shortcut because they have a preset wallpaper, the app saves a bright red image saying "SET THIS AS YOUR WALLPAPER" to their Photos. The user must manually set this as their lock screen first. Once a photo is set, the Shortcut works flawlessly.
- **Permissions:** The flow forcefully ensures users grant 3 permissions (Shortcuts Home Screen folder, Shortcuts Lock Screen folder, and Notifications).

## 6. Business, Monetization & Analytics
- **Monetization Strategy:** NoteWall uses a **Hard Paywall** powered by Superwall for UI and RevenueCat for subscription management (Monthly or Lifetime "NoteWall+"). 
- **Free Limits:** The `freeExportLimit` is technically **0**. Users must subscribe to export/set their wallpapers. The paywall triggers on launch (if setup is complete), on tap, or on exit intercepts (offering a discount).
- **Analytics:** Uses Mixpanel for in-app events. There is also a standalone Next.js 14 web dashboard (`notewall-analytics-dashboard`) hosted on Vercel to track funnel health, DAU, and Paywall CR.
- **Tech Stack Keywords:** Native Swift, SwiftUI, Apple Shortcuts, iOS 15.0+, RevenueCat, Superwall, Mixpanel, AppStorage/UserDefaults (No backend DB).
