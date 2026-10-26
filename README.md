# Stride

iPhone app for walk, jog, and run stats from Apple Health.

Stride classifies movement by speed, lists real sessions (not indoor wandering), and shows day, week, and month totals. Built with SwiftUI for iOS 18.

## Features

- **Stats**
  - **Today** — steps, distance, energy, and walk / jog / run for the current day
  - **Week** — Sunday–Saturday calendar week, swipe between weeks, tap a day
  - **Month** — month totals plus week tiles (newest first); tap a week to open it
- **Sessions** — listed walks, jogs, and runs with a detail screen (speed, pace, tempo, graph)
- **You** — step goal, units, speed thresholds, and session rules (min duration and join gaps)

Walk, jog, and run tiles hide when that kind has no data. Walk sessions only list a steady walk, not pacing around home or the office.

## Requirements

- macOS with Xcode 16+
- iOS 18 iPhone (HealthKit; a physical device works best)
- Apple ID / development team for signing

## Run

```bash
brew install xcodegen   # if needed
xcodegen generate
open Stride.xcodeproj
```

Select your development team in Xcode, then run on a device. On first launch, allow Health access for steps, distance, walking/running speed, energy, and workouts.

Pull to refresh Stats after granting access.

## How activity is classified

Defaults (editable in **You**):

| Kind | Speed |
| --- | --- |
| Walk | under 5 km/h |
| Jog | 5–8 km/h |
| Run | over 8 km/h |

Sessions are merged across short gaps and only listed if they last long enough (walk 10 min, jog/run 5 min by default). Health data is loaded into memory on launch and refresh; switching Today / Week / Month does not query Health again.

## Project

| | |
| --- | --- |
| Bundle ID | `com.mujassir.stride` |
| Project spec | `project.yml` (XcodeGen) |
| License | [Apache 2.0](LICENSE) |
