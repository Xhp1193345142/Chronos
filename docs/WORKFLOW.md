# Vibe coding workflow

## One task at a time

Use one coding conversation as the writer on `dev`. Other conversations may inspect and review but must not modify files. Since the project uses only `dev`, do not start multiple writing worktrees or branches in parallel. Integrate and commit one task before starting the next.

Each task should state:

1. User-visible outcome and affected screen or module.
2. Acceptance criteria, including an error or empty state.
3. Files or architecture boundary that must remain stable.
4. How to verify the result on a device or with an automated check.

## Delivery loop

1. Read the relevant docs; inspect `git status` and the current implementation.
2. Make the smallest coherent change. Keep fixtures separate from production data sources.
3. Run formatting, analysis, relevant tests, and a visual check when a UI changes.
4. Review the diff for unrelated changes, secrets, misleading copy, and broken permission behavior.
5. Commit on `dev` with a descriptive message; push `dev`; check the GitHub Actions result and report verification and remaining limitations.

For Android device checks, use a stable debug signing key and `make run-android DEVICE=<id>`. This builds the APK and installs it with `adb install -r`, which stops on a signature mismatch. Do not use `flutter run` against a device that may hold Chronos records: Flutter may uninstall the installed app automatically after a signature conflict, deleting app-local data. Never uninstall or clear app data to make a test install succeed.

## Reusable task prompt

> Read `AGENTS.md` and the relevant Chronos docs. Implement **[one user-visible outcome]** on the existing `dev` branch without creating branches. Acceptance: **[observable behavior]**. Preserve **[explicit boundary]**. Run relevant formatting, analysis, tests, and a visual check. Report changed files, observed results, and anything not verified. Commit and push only after checks pass.

## Review prompt

> Review the current `dev` diff read-only. Prioritize behavioral bugs, privacy boundary violations, platform assumptions, regressions, and missing verification. Do not edit files or create a branch. Give precise file/line findings.
