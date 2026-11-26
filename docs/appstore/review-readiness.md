# App Review readiness: RunCheck 1.1.0 (build 3)

Checked on November 26, 2026 against the App Review Guidelines, the code and the App Store Connect record (app ID 6838771772). What's entered there is in `metadata.md`.

## Lessons from earlier reviews

- **Unreachable features still count.** GPS workout code stays excluded from the 1.x target in `project.yml`.
- **HealthKit needs both purpose strings.** Read + update strings remain; the update string says RunCheck doesn't write.
- **Privacy "collected data" means off-device.** Still empty; App Privacy stays **Data Not Collected**. The App Store update check sends only the app ID and country.
- **New version does not inherit the screen recording attachment.** Record and attach again for 1.1.0.

## Checklist

| Area | Guideline | Status |
|---|---|---|
| Version bump | — | **Done.** `project.yml` → MARKETING_VERSION 1.1.0, CURRENT_PROJECT_VERSION 3; XcodeGen regenerated. |
| Archive + upload | — | **Done.** Release archive uploaded; App Store Connect accepted build 1.1.0 (3). |
| ASC version 1.1.0 created | — | **Done.** Prepare for Submission. |
| What's New / promo / description / notes | 2.3, 2.1 | **Done.** Saved in ASC; copies in `metadata.md` and `review-notes.md`. Removed inaccurate "no internet" claims. |
| Build attached | — | **Done.** Build 3 attached to version 1.1.0. |
| Screen recording attachment | 2.1 | **To do (you).** Attachments do not carry over. See shot list below. |
| Permissions match features | 2.5.4, 5.1.1 | OK. HealthKit read only; LocationService still excluded from the target. |
| Privacy manifest | ITMS-91053 | OK. UserDefaults CA92.1; no collected data; tracking false. |
| Export compliance | — | OK. `ITSAppUsesNonExemptEncryption = NO`. |
| Release hygiene | ITMS-91306 | OK. `MTL_ENABLE_DEBUG_INFO = NO` in Release. Build 3 > build 2. |
| Mac / Vision Pro | 2.4.5 | OK. Off in project and availability. |
| Accounts, IAP, UGC | 5.1.1(v), 3.1.1, 1.2 | Not applicable. |
| Medical claims | 1.4.1 | OK. Stats only. |
| Privacy / support URLs | 5.1.1(i), 1.5 | OK. Both return 200. |
| App Privacy published | 5.1.1 | OK from 1.0.0 (Data Not Collected). |
| Screenshots | 2.3.3 | Copied from 1.0.0. Optional: refresh to show Summary rings and a focus tab. |
| Submit for Review | — | **To do.** Confirm with you after build + recording are attached. |

## Screen recording: what to record

On a physical iPhone with build 3 from TestFlight:

1. Start Screen Recording from Control Center, then go to the Home Screen.
2. Open RunCheck (delete/reinstall from TestFlight first if you want onboarding in the clip).
3. Allow Health if prompted. Show Summary: Today, Week, Month, rings and walk/jog/run tiles.
4. You → Tabs: turn on Jogging or Steps, then open that tab and show Daily/Week.
5. Sessions: open one session detail.
6. You → About: Check for Updates and Privacy Policy.
7. Stop, AirDrop to the Mac, rename to a lowercase `.mp4`, drag onto **App Review Information → Attachment**.
