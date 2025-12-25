# Firebase Analytics Implementation for NoteWall

## Overview

This document describes the Firebase Analytics (GA4) implementation for tracking onboarding and paywall conversion funnels in NoteWall.

## Setup Instructions

### 1. Add Firebase SDK via Swift Package Manager

1. In Xcode: **File > Add Package Dependencies**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: **10.0.0** or later
4. Choose products:
   - ✅ **FirebaseAnalytics**
   - ✅ **FirebaseCore**
5. Click **Add Package**

### 2. Add GoogleService-Info.plist

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or select existing one
3. Add iOS app with your bundle ID
4. Download `GoogleService-Info.plist`
5. Drag it into the NoteWall folder in Xcode
6. Ensure:
   - ✅ "Copy items if needed" is checked
   - ✅ Target "NoteWall" is selected

### 3. Configuration (Already Implemented)

Firebase is configured in `NoteWallApp.swift`:

```swift
init() {
    // IMPORTANT: Configure Firebase FIRST before any other Firebase services
    FirebaseSetup.shared.configure()
    
    // ... rest of init
}
```

## Verification Checklist

### Pre-Flight Checks

- [ ] `GoogleService-Info.plist` is in the project and added to NoteWall target
- [ ] Firebase SPM packages added: `FirebaseCore`, `FirebaseAnalytics`
- [ ] `FirebaseSetup.shared.configure()` called in `NoteWallApp.init()` BEFORE other Firebase calls

### Enable Debug View (Real-Time Event Verification)

1. In Xcode: **Edit Scheme > Run > Arguments > Arguments Passed On Launch**
2. Add: `-FIRAnalyticsDebugEnabled`
3. Build and run the app
4. Events will appear in Firebase Console > Analytics > DebugView within seconds

### Verify Events Are Firing

1. Build and run with `-FIRAnalyticsDebugEnabled` flag
2. Open Firebase Console > Analytics > DebugView
3. Select your test device (appears after app launches)
4. Walk through onboarding and watch events appear in real-time

## Analytics Events

### Onboarding Funnel Events

| Event | Description | Key Parameters |
|-------|-------------|----------------|
| `onboarding_start` | User starts onboarding (fires once) | `flow_id`, `variant_id` |
| `onboarding_step_view` | Step becomes visible | `step_id`, `step_index`, `step_name` |
| `onboarding_step_complete` | Step completed | `step_id`, `step_index`, `duration_ms` |
| `onboarding_action` | Any action (next/back/skip) | `action`, `step_id` |
| `quiz_answer` | Quiz question answered | `question`, `answer`, `step_id` |
| `permission_prompt` | Permission shown/accepted/denied | `permission_type`, `action` |
| `onboarding_abandon` | User abandons mid-onboarding | `step_id`, `reason`, `total_duration_ms` |
| `onboarding_complete` | Onboarding completed | `total_duration_ms` |

### Paywall Funnel Events

| Event | Description | Key Parameters |
|-------|-------------|----------------|
| `paywall_impression` | Paywall displayed | `paywall_id`, `trigger`, `placement` |
| `plan_selected` | User selects a plan | `product_id`, `price`, `period`, `currency` |
| `purchase_start` | Purchase flow initiated | `product_id` |
| `purchase_success` | Purchase completed | `product_id`, `revenue`, `currency` |
| `purchase_cancel` | User cancelled purchase | `product_id` |
| `purchase_fail` | Purchase failed | `product_id`, `error_code` |
| `restore_tap` | Restore button tapped | - |
| `restore_success` | Restore successful | - |
| `restore_fail` | Restore failed | `error_code` |
| `paywall_close` | Paywall dismissed | `paywall_id`, `converted` |

### Screen View Events

| Event | Description | Key Parameters |
|-------|-------------|----------------|
| `screen_view` | Screen viewed | `screen_name`, `screen_class` |

### Feature Usage Events

| Event | Description | Key Parameters |
|-------|-------------|----------------|
| `feature_usage` | Feature used | `feature` |
| `wallpaper_export` | Wallpaper exported | `count`, `is_premium` |
| `shortcut_run` | Shortcut executed | `success` |

## Key Funnels to Build in Firebase Console

### 1. Onboarding Completion Funnel

```
onboarding_start → onboarding_step_view (step_index=0) → ... → onboarding_complete
```

- Filter by `flow_id` / `variant_id` for A/B testing
- Identify drop-off points by `step_id`

### 2. Paywall Conversion Funnel

```
paywall_impression → plan_selected → purchase_start → purchase_success
```

- Filter by `paywall_id` (post_onboarding, limit_reached, etc.)
- Filter by `trigger` to see what brought users to paywall

### 3. Onboarding Drop-Off Analysis

```
onboarding_start → onboarding_abandon (group by step_id)
```

- Group by `step_id` to identify problematic steps
- Use `total_duration_ms` to understand time spent before abandoning

### 4. Quiz Completion

Track `quiz_answer` events grouped by `step_id` to see:
- Which quiz questions have lowest completion
- Most common answers for each question

### 5. Permission Acceptance Rate

```
permission_prompt (action=shown) vs permission_prompt (action=accepted)
```

Filter by `permission_type` (notifications, photo_library, etc.)

## User Properties

| Property | Description |
|----------|-------------|
| `is_premium` | Whether user has premium access |
| `has_completed_onboarding` | Whether onboarding was completed |
| `app_version` | Current app version |
| `device_model` | Device model |
| `ios_version` | iOS version |
| `install_date` | First app launch date |

## Debug Mode

In DEBUG builds:
- All events are logged to console with `📊` prefix
- Events are still sent to Firebase (can be disabled)
- Use `-FIRAnalyticsDebugEnabled` for real-time DebugView

To disable sending in DEBUG:
```swift
// In FirebaseSetup.swift
#if DEBUG
Analytics.setAnalyticsCollectionEnabled(false)
#endif
```

## Files Structure

```
NoteWall/
├── Analytics/
│   ├── AnalyticsService.swift      # Main analytics wrapper
│   ├── AnalyticsEvent.swift        # Type-safe event definitions
│   ├── AnalyticsProperty.swift     # Property keys & step IDs
│   ├── AnalyticsViewModifiers.swift # SwiftUI modifiers
│   ├── FirebaseSetup.swift         # Firebase configuration
│   └── OnboardingView+Analytics.swift # Onboarding tracking helpers
├── FIREBASE_ANALYTICS_README.md    # This file
```

## Testing Checklist

### Onboarding Flow

- [ ] `onboarding_start` fires when opening onboarding
- [ ] `onboarding_step_view` fires for each step
- [ ] `onboarding_action` fires for next/back buttons
- [ ] `quiz_answer` fires for quiz selections
- [ ] `onboarding_step_complete` fires with duration when leaving step
- [ ] `onboarding_complete` fires at the end
- [ ] `onboarding_abandon` fires if app backgrounded mid-flow

### Paywall Flow

- [ ] `paywall_impression` fires when paywall opens
- [ ] `plan_selected` fires when tapping a plan option
- [ ] `purchase_start` fires when starting purchase
- [ ] `purchase_success` fires on successful purchase
- [ ] `purchase_cancel` fires if user cancels
- [ ] `restore_tap` fires when tapping restore
- [ ] `paywall_close` fires when dismissing paywall

## Troubleshooting

### Events Not Appearing in DebugView

1. Ensure `-FIRAnalyticsDebugEnabled` is in launch arguments
2. Check console for `🔥 Firebase:` logs
3. Verify `GoogleService-Info.plist` is in target
4. Wait 30-60 seconds after event (there can be slight delay)

### Duplicate Events

The implementation includes "fire-once" mechanisms to prevent duplicate events from SwiftUI re-renders. If you still see duplicates:
1. Check that you're not calling tracking methods manually when modifiers are used
2. Verify `hasTracked` state is being preserved correctly

### Events Missing Parameters

1. Check Firebase Analytics limits:
   - Event name: max 40 characters
   - Parameter name: max 40 characters
   - Parameter value (string): max 100 characters
   - Max 25 parameters per event
2. The `AnalyticsService` automatically sanitizes to comply with limits

## Support

For issues with this implementation, check:
1. Console logs for `📊` analytics messages
2. Firebase Console > Analytics > DebugView
3. Firebase Console > Analytics > Events (data appears within 24h for non-debug)
