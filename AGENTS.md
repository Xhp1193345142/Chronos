# Chronos development rules

Read `README.md` and the relevant file in `docs/` before changing code. The product is a privacy-conscious screen-time app for iOS and Android. Flutter owns shared UI; platform APIs stay behind platform-specific adapters.

## Git and collaboration

- `dev` is the only development branch. Do not create another branch or commit on another branch.
- Only one coding session may write to this checkout at a time. Other sessions may review read-only. Before editing, run `git status --short --branch` and preserve unrelated changes.
- Keep each change focused. Finish with a reviewable diff, relevant checks, and a commit on `dev`. Push `dev` after a successful commit when remote access is available. Never force-push.
- Never reset, stash, delete, or overwrite someone else's uncommitted work to make the tree clean.

## Product and architecture

- Follow `docs/PRODUCT.md` for scope, `docs/ARCHITECTURE.md` for data boundaries, and `docs/DESIGN.md` for UI behavior.
- The demo uses explicitly labeled sample data. Do not present it as live device usage or silently substitute sample data after a permission failure.
- Keep iOS Screen Time data inside Apple's permitted surfaces. Do not attempt to extract report-extension data or send it to an AI service.
- Store usage-related data locally by default. Do not add analytics, accounts, a backend, AI calls, or third-party tracking without a specific product decision.
- Never commit secrets, signing files, or personal device data.

## Completion checks

- Run `dart format .`, `flutter analyze`, and relevant `flutter test` tests after code changes when Flutter is available.
- When implementing real data flows, verify loading, no data, denied permission, and sample mode. Test native authorization and notifications on physical devices before claiming they work.
- Report what changed, the commands run and their results, and any unverified platform behavior. Do not claim a build or device test succeeded unless observed.
