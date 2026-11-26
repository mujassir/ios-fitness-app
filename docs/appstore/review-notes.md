# App Review notes: RunCheck 1.1.0

Paste everything inside the block into **App Review Information → Notes** (plain text, under 4,000 characters).

```
1. SCREEN RECORDING
Attached in the App Review attachments: recorded on a physical iPhone running the latest iOS. It starts by launching RunCheck from the Home Screen and shows onboarding (if needed), the Apple Health permission sheet, Summary (Today/Week/Month with rings and walk/jog/run tiles), the optional Running, Jogging, Walk, Steps and Energy tabs, Sessions with a session detail, and the You tab (Tabs, Goals, units, speed thresholds, Apple Health status, Check for Updates, Privacy Policy). RunCheck has no accounts, no user-generated content and no paid content.

2. PURPOSE AND TARGET AUDIENCE
RunCheck is a stats app for people who walk, jog or run and want a simple, private view of that activity. It reads the data their iPhone and Apple Watch already save to Apple Health, sorts movement into walk, jog and run sessions by speed, and shows daily, weekly and monthly totals on Summary plus optional focus tabs. Casual indoor steps are kept separate from real sessions. There is no account or subscription, and it works offline.

3. SETUP AND MAIN FEATURES
No login is needed. No sample files are needed.
RunCheck shows data that already exists in Apple Health. On a device with an empty Health history the screens show zeros. Any iPhone that has been carried for a day, or an Apple Watch, provides steps, distance and workouts.
a) Launch RunCheck and tap Continue on the onboarding screen (or open Summary if already onboarded).
b) The Apple Health sheet asks for read access only. Tap Turn On All, then Allow.
c) Summary: switch between Today, Week and Month. Rings show goals; tiles show walk, jog and run. Tap a session in Sessions.
d) You → Tabs: turn on Running, Jogging, Walk, Steps or Energy to show those tabs. Each has its own Daily/Week/Month views and goals.
e) You → About: Check for Updates, Privacy Policy and Support.

NEW IN 1.1.0
- Optional focus tabs (Running, Jogging, Walk, Steps, Energy) with per-kind goals for day, week and month. Only Running is on by default; enable the others in You → Tabs.
- Summary rings for each enabled tab. Sessions remain a separate tab.
- Daily App Store update check (itunes.apple.com/lookup, app ID and country only) with an alert and a Check for Updates button in About.
- Re-prompt for any unanswered Health read types; if access was granted but Health returns no data, a banner points to Health → Apps → RunCheck.

4. EXTERNAL SERVICES
None. The only network request is an update check to Apple's App Store lookup service (itunes.apple.com/lookup, app ID and country code only), at most once a day, which shows an "Update available" alert linking to the App Store. RunCheck includes no third-party SDKs, analytics, advertising, authentication, payment or AI services. Everything runs on the device using Apple frameworks (HealthKit, SwiftUI, Swift Charts).

5. REGIONAL DIFFERENCES
None. The app works the same in every region where it is available. Distance can be shown in kilometres or miles.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. RunCheck is not a medical device, gives no medical advice, and ships no third-party content.

Permissions: Apple Health, read only (steps, walking and running distance, walking and running speed, active energy, exercise minutes, workouts) to calculate the stats. RunCheck does not write to Apple Health. The NSHealthUpdateUsageDescription string is present only because the HealthKit entitlement requires it. RunCheck does not use location, motion, camera, microphone, contacts or notifications. HealthKit background delivery is used only to refresh step totals when Health gets new data. Health data never leaves the device, is never stored in iCloud, and is never used for advertising.
Privacy policy: https://mujassir.com/runcheck/privacy/
```
