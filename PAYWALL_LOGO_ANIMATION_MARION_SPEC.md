# Paywall Logo Animation (Marion/Motion Spec)

This document captures the **exact animation behavior** currently used by the paywall logo so it can be recreated as a Lottie animation.

Source of truth:
- `NoteWall/AppIconAnimationView.swift`
- `NoteWall/PaywallView.swift`

---

## 1) Where this animation is used

1. Main paywall header logo
   - `AppIconAnimationView(size: 160)` in `PaywallView.logoHeader`
2. Lifetime sheet logo
   - `AppIconAnimationView(size: 100)` plus an extra slow float (`floatingOffset`)

---

## 2) Core logo animation (exact math)

The core icon motion is time-driven in `AppIconAnimationView` with:
- loop duration (`cycle`) = **3.0s**
- update rate = **120 Hz** (`1/120s` timer)

### Time + phases

- `t = animationTime`
- `phase1 = t * 2π / cycle`
- `phase2 = t * 2π / cycle * 0.6`
- `phase3 = t * 2π / cycle * 1.4`

### Motion channels

- `angleX = sin(phase1) * 14 + sin(phase3) * 4` (degrees)
- `angleY = cos(phase2) * 12 + sin(phase1 * 1.3) * 3` (degrees)
- `translateZ = sin(phase1 * 0.8) * 10`
- `shadowIntensity = 0.12 + sin(phase1) * 0.04`

Applied transforms:
- `rotation3DEffect(.degrees(angleX), axis: (1,0,0), perspective: 0.7)`
- `rotation3DEffect(.degrees(angleY), axis: (0,1,0), perspective: 0.7)`
- Vertical drift: `translationY = translateZ * 0.08`

So effective Y drift amplitude is:
- `10 * 0.08 = ±0.8 pt`

### Shadow animation

- Opacity = `shadowIntensity`
- Blur radius = `7 + sin(phase1) * 2`
- X offset = `sin(angleY * π / 180) * 2.5`
- Y offset = `3 + sin(angleX * π / 180) * 1.5`

---

## 3) Visual construction (icon layer)

- Shape: rounded rectangle mask
- Corner radius: `size * 0.22`
- Icon source: `UIImage(named: "OnboardingLogo") ?? UIImage(named: "AppIcon")`
- If icon missing: fallback gradient block + `video.fill` symbol

Sizes in paywall contexts:
- Main paywall: `size = 160`
- Lifetime sheet: `size = 100`

---

## 4) Extra motion in Lifetime sheet only

In `LifetimePlanSheet` (inside `PaywallView.swift`) there is an additional container float:

- `floatingOffset` starts at `0`
- animated with: `.easeInOut(duration: 3).repeatForever(autoreverses: true)`
- target value: `floatingOffset = -8`

This means the logo block in lifetime sheet moves up/down by **8 pt peak**, independent of the core wobble above.

---

## 5) Lottie recreation guidance (1:1 intent)

To match current behavior as closely as possible:

1. Composition
   - Duration: `3.0s`
   - FPS: `60` (or `120` if your pipeline supports it)
   - Loop: infinite

2. Rotation channels
   - X rotation follows: `sin(2πt/3)*14 + sin(2πt/3*1.4)*4`
   - Y rotation follows: `cos(2πt/3*0.6)*12 + sin((2πt/3)*1.3)*3`

3. Vertical drift
   - `y = sin((2πt/3)*0.8) * 0.8` (in points-equivalent)

4. Shadow
   - Opacity: `0.12 + sin(2πt/3)*0.04`
   - Blur: `7 + sin(2πt/3)*2`
   - X: `sin(yRotationRadians)*2.5`
   - Y: `3 + sin(xRotationRadians)*1.5`

5. Lifetime sheet variant only
   - Add parent group Y animation: `0 ↔ -8`, easeInOut, 3s, autoreverse, loop

---

## 6) Notes for implementation parity

- The current SwiftUI animation is continuous math-driven (not discrete keyframes).
- For best parity in Lottie, bake many keyframes (every 1–2 frames) from these formulas.
- Keep corner radius proportional (`22%` of icon size) to preserve visual feel at multiple sizes.
