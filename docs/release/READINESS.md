# Release standard and evidence

Owner: Elton. Decision recorded 2026-11-05: prepare both iOS and Android to a commercial release standard; current product is free. No store submission or billing integration is requested.

Current delivery priority: Android first; iOS work is deferred by the user. `make release-check-android` excludes Xcode/iPhone gates and uses the Android-specific profile flag. The all-platform report retains iOS gaps for future work.

## Product boundary

The dependable shared product is a local time journal with timing, pause/resume, notes, backfill, history, seven-day trends and user-controlled backup. Android device usage and goals are optional. Do not market unverified usage accuracy or background delivery as a guaranteed capability. iOS starts in the genuine journal, not a screen-time demo; protected device usage remains a separate unfinished module.

## Acceptance gates

| Gate | Evidence or next action |
| --- | --- |
| Durable storage and migration | Native SQLite transactions; strict legacy validation; old preferences removed only after commit. Database reopen and clear/no-resurrection tests passed. L60 Android 13 upgrade preserved all existing rows; integrity `ok`. iOS native migration still pending. |
| Failed writes | Controller publishes state only after durable commit. Fault-injection tests passed for failed pause/stop/delete and recovery. Serialized mutations prevent duplicate timers. Clock rollback and editing paused records also covered. Real low-storage/OS termination testing remains pending. |
| Backup and recovery | Android JSON saved through DocumentsUI and restored idempotently with exact row comparison and integrity `ok`. CSV native picker cancellation observed; completed CSV save still pending. Tests cover duplicate skip, conflicts/overlap atomic refusal and running snapshots. iOS file flow pending. |
| Export privacy | Backup is plain text and contains private notes. No automatic upload; cloud providers may appear in the OS picker. Never upload a real backup as evidence. |
| Independent manual mode | iOS journal default; Android can remember manual-only mode. Permission denial must not prevent timing or history. |
| Deletion | Explicit confirmation; clear SQLite and legacy payload; targets/system histories remain correctly described. Never test destructive deletion on the user's real history. |
| Help and privacy | In-app local document and public support project. Publish the static privacy document to a stable HTTPS address before a real submission. Add a private support email when available. |
| Android binary | Production release must have real signing; no debug fallback. Debug APK is review-only. Target API, merged permissions and native-library 16 KB alignment must be checked for each production artifact. |
| Android device usage | Event-based natural-day accounting replaces misaligned OS buckets; boundary/lock/restart/conflict tests and L60 display check passed. Independent system-report comparison on two devices/OEMs and across midnight remains pending. |
| Notifications | L60 Android 13: actual usage exceeded a temporary 30-minute goal; a real system notification was observed. Forced repeated JobScheduler runs preserved the same notification record/timestamps; tapping returned to goals. Temporary goal removed. Day reset, revoked permission, reboot and natural scheduling delays remain pending. |
| iOS | Full Xcode + iPhone unavailable. Build/archive, SQLite migration, file picker, lifecycle, VoiceOver and real-device checks pending. Family Controls distribution entitlement and protected extensions needed for device-usage feature. |
| Performance | Profile/release scrolling, cold/warm start, 10k-record history, low storage, large text and reduced motion; pending. Debug visual inspection is insufficient. |
| Store identity | Developer Elton, current free product, no accounts or billing. Account, final signing, store IDs and policy URL filled only when preparing actual distribution. |

Run `make release-check` for a read-only report. A pending gate is not an app-store approval. Set verification flags in `config.json` only after recording device, OS, date, build and result here or in implementation status.

## Build commands

- `make check`: format check, analyze, tests.
- `make build-apk`: local debug review build.
- `make build-aab`: Android production bundle; requires `CHRONOS_KEYSTORE_PATH`, `CHRONOS_KEYSTORE_PASSWORD`, `CHRONOS_KEY_ALIAS`, `CHRONOS_KEY_PASSWORD` in the local environment. Never put passwords in command history or source control. Signing belongs outside the checkout.
- `make build-ios`: iOS archive with full Xcode and an appropriate Apple team/profile.

Keep the existing debug installation for user records. A production certificate differs from the debug key and cannot cover-install the same package. Never uninstall the user’s debug app to resolve that conflict; export and verify a restorable journal first, then plan the transition explicitly.

## Current primary references

- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/): completeness, privacy and accurate feature descriptions; actual acceptance needs review.
- [Google Play review preparation](https://support.google.com/googleplay/android-developer/answer/9859455): privacy URL, content and access declarations.
- [Google Play personal-account testing](https://support.google.com/googleplay/android-developer/answer/14151465): applies to eligible new personal accounts; confirm against the eventual account.
- [Android native-library page-size guidance](https://developer.android.com/guide/practices/page-sizes): inspect production libraries and verify on a 16 KB environment.

Recheck policies at actual submission time. Region-specific store requirements remain a distribution task, not a reason to collect additional user data in the app.

## Android test commands

`make test-android` runs framework-independent accounting tests with a configured JDK. CI also builds the debug APK. `make build-android-test` builds an optional AndroidX runner APK. Install the main/test APKs with signature-matched `adb install -r`; never use an installer that uninstalls the user's app on mismatch. The optional device test requires usage/notification permissions and at least 15 minutes of real Chronos use; it creates/deletes only a UUID-named temporary goal. Analytics are disabled for the runner. Inspect skipped tests rather than treating them as accepted features.

On the current L60, the AndroidX process remained in `<pre-initialized>` before executing tests. Both normal and storage-compatibility attempts were stopped without clearing app data. Instrumentation therefore has no passed device result. The notification evidence above came from the actual app UI, system notification record and `cmd jobscheduler run -f`, not from a simulated threshold or a claimed successful runner. Forced execution does not validate the normal 15-minute scheduling delay.
