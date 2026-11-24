# App Review readiness: RunCheck 1.0.0 (build 2)

Checked on November 25, 2026 against the App Review Guidelines, the code and the App Store Connect record (app ID 6838771772). What's entered there is in `metadata.md`.

## Lessons from this review prep

- **Unreachable features still count.** The GPS workout screen was in the code but had no tab, yet the build declared background location and asked for Motion and Health write access. That is a 2.5.4 / 5.1.1 rejection. For 1.0 the workout code is excluded from the target in `project.yml` (kept in the repo for a later version), and the permissions are gone.
- **HealthKit needs both purpose strings.** The upload fails without `NSHealthUpdateUsageDescription`, even for a read-only app. The string says plainly that RunCheck doesn't write.
- **The privacy manifest's "collected data" means data sent off the device.** RunCheck sends nothing, so `NSPrivacyCollectedDataTypes` is empty, and the App Privacy label should be **Data Not Collected**.

## Checklist

| Area | Guideline | Status |
|---|---|---|
| Builds and launches; onboarding → Health sheet → Stats → You | 2.1 | OK in the simulator (iPhone 17 Pro Max, iOS 26.5). **To do (you):** test build 2 from TestFlight on a real iPhone that has Health data. |
| Device name matches the App Store name | 2.3.7 | **Fixed.** Home Screen name, onboarding title and About now say RunCheck (was Stride). |
| Features match the permissions | 2.5.4, 5.1.1 | **Fixed.** Removed background location, the location and motion strings, the `location-services` device capability, and Health write access. The workout code is excluded from the build. |
| Health permission strings | 5.1.1(iii) | **Fixed.** The read string is specific. The update string says RunCheck doesn't write. |
| Health data in iCloud or used for ads | 2.5.1, 5.1.3 | OK. SwiftData store removed; only settings in UserDefaults. No network. |
| Clinical Health Records | 2.5.1 | OK. Entitlement removed earlier. |
| Network, SDKs, tracking | 5.1.1, 5.1.2 | OK. No URLSession, no third-party packages. |
| Privacy manifest | ITMS-91053 | **Fixed.** UserDefaults CA92.1 declared; no collected data; tracking false. |
| Privacy policy link in the app | 5.1.1(i) | **Fixed.** You → About → Privacy Policy and Support. |
| Privacy policy and support pages are live | 5.1.1(i), 1.5 | **To do.** Both return 404: `docs/` isn't committed or pushed, and GitHub Pages is off. Commit, push to `main`, then turn on Pages from `main` → `/docs`. URLs are already entered in App Store Connect. |
| Export compliance | — | OK. `ITSAppUsesNonExemptEncryption = NO`. |
| Release build hygiene | ITMS-91306 | OK. `MTL_ENABLE_DEBUG_INFO = NO` in Release. Build 2 is above build 1. |
| Mac / Vision Pro | 2.4.5 | OK. Off in the project and in Pricing and Availability. |
| Accounts, IAP, user content | 5.1.1(v), 3.1.1, 1.2 | Not applicable. |
| Medical claims | 1.4.1 | OK. Stats only, no medical advice. |
| Screenshots (iPhone slot: 1206 × 2622 or 1179 × 2556) | 2.3.3 | **To do (you).** Slot is empty. iPhone only; no iPad slot needed. |
| Name, subtitle, keywords, description | 2.3.1, 2.3.7 | **Done.** Promotional text, description, keywords, support URL and copyright entered (`metadata.md`). No other apps' names, no GPS or workout saving, "Apple Health" only in the description. |
| Content Rights, age rating, category | 1.3 | **Done.** No third-party content. Age rating 4+ (all None / No). Health & Fitness, Sports. |
| App Privacy answers **Published** (Data Not Collected) | 5.1.1 | Answered "Data Not Collected" and privacy URL saved. **To do (you):** click **Publish** on App Privacy. |
| Build 2 attached to version 1.0.0 | — | **Done.** The version was created as "1.0", which hid the 1.0.0 builds; it's now 1.0.0 and build 2 is attached. |
| Review notes | 2.1 | **Done.** Entered in App Store Connect from `review-notes.md` (3,090 characters, all six points). Sign-in required is off. |
| Screen recording attachment | 2.1 | **To do (you).** See below. |
| App Review contact (name, phone, email) | 2.1 | **To do (you).** Empty in App Store Connect; required to submit. |
| Pricing and availability | — | **Done.** Free; 147 countries or regions (no EU, no China mainland), like the other apps on this account. |
| Regulated Medical Device declaration | — | **To do (you).** App Compliance asks every Health & Fitness app. RunCheck isn't one: it shows activity stats and gives no diagnosis or treatment. |

## Screen recording: what to record

On a physical iPhone with build 2 from TestFlight:

1. Start Screen Recording from Control Center, then go to the Home Screen.
2. Open RunCheck. If you've already been through onboarding, delete and reinstall it from TestFlight first, so the recording shows onboarding.
3. Tap Continue. On the Health sheet, tap Turn On All, then Allow.
4. Stats tab: show Today, then Week, then Month. Scroll to Sessions and open one session.
5. You tab: change the step goal and go back to Stats to show it changed. Scroll to Apple Health and About, then tap Privacy Policy.
6. Stop the recording. AirDrop it to the Mac, rename it with a lowercase `.mp4` extension, and drag it onto **App Review Information → Attachment**.

## Optional

- The white "Continue" label on the bright green onboarding button has low contrast. Dark text would read better.
- For 1.1: put the Move tab back with GPS workouts. Then restore the location strings and background mode, add Health write access, and record a new screen recording.
