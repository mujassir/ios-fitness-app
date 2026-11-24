# App Review notes: RunCheck 1.0.0

Paste everything inside the block into **App Review Information → Notes** (plain text, under 4,000 characters).

```
1. SCREEN RECORDING
Attached in the App Review attachments: recorded on a physical iPhone running the latest iOS. It starts by launching RunCheck from the Home Screen and shows onboarding, the Apple Health permission sheet, the Stats tab (Today, Week and Month, the step ring, and the walk, jog and run sessions with their details), and the You tab (step goal, units, speed thresholds, Apple Health status, and the Privacy Policy link). RunCheck has no accounts, no user-generated content and no paid content.

2. PURPOSE AND TARGET AUDIENCE
RunCheck is a stats app for people who walk, jog or run and want a simple, private view of that activity. It reads the data their iPhone and Apple Watch already save to Apple Health, sorts movement into walk, jog and run sessions by speed, and shows daily, weekly and monthly totals. Casual indoor steps are kept separate from real sessions. There is no account, subscription or internet connection.

3. SETUP AND MAIN FEATURES
No login is needed. No sample files are needed.
RunCheck shows data that already exists in Apple Health. On a device with an empty Health history the screens show zeros. Any iPhone that has been carried for a day, or an Apple Watch, provides steps, distance and workouts.
a) Launch RunCheck and tap Continue on the onboarding screen.
b) The Apple Health sheet asks for read access only. Tap Turn On All, then Allow.
c) Stats tab: switch between Today, Week and Month. The ring shows steps against the daily goal. The tiles show distance, energy and active time. The Sessions list shows walk, jog and run sessions found in Health. Tap a session to see its details.
d) You tab: change the step goal, units, body weight (used to estimate energy) and the jog and run speed thresholds. The Stats tab updates right away. "Manage access in Health" opens the Health app. Privacy Policy and Support links are at the bottom.

4. EXTERNAL SERVICES
None. RunCheck makes no network requests and includes no third-party SDKs, analytics, advertising, authentication, payment or AI services. Everything runs on the device using Apple frameworks (HealthKit, SwiftUI, Swift Charts).

5. REGIONAL DIFFERENCES
None. The app works the same in every region where it is available. Distance can be shown in kilometres or miles.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. RunCheck is not a medical device, gives no medical advice, and ships no third-party content.

Permissions: Apple Health, read only (steps, walking and running distance, walking and running speed, active energy, exercise minutes, workouts) to calculate the stats. RunCheck does not write to Apple Health. The NSHealthUpdateUsageDescription string is present only because the HealthKit entitlement requires it. RunCheck does not use location, motion, camera, microphone, contacts or notifications. HealthKit background delivery is used only to refresh step totals when Health gets new data. Health data never leaves the device, is never stored in iCloud, and is never used for advertising.
Privacy policy: https://mujassir.github.io/ios-fitness-app/privacy
```
