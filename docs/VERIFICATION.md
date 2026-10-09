# Local verification — 2026-10-09

Verified on arm64 macOS using Apple Swift 6.3.3. Only Command Line Tools were installed; `xcodebuild -version` reported that full Xcode is required. No iOS target or iOS build is claimed. GitHub Actions is configured, but has not run remotely.

## Completed

- `swift build`: compiled and linked the real SwiftUI application.
- `swift build --disable-sandbox -c release`: compiled and linked the Release application.
- `./scripts/package-app.sh --disable-sandbox`: produced `dist/DevScope.app`, an unsigned local macOS bundle.
- `./scripts/test.sh --disable-sandbox`: **9/9 Swift Testing cases passed**, including parser malformed inputs and overflow, CPU percentages and counter wraparound, saved-task round trip, real script stdout/stderr capture and exit code 7, persistent output logs, invalid-script rejection, concurrent-run rejection, SIGTERM stopping and actual Mach/ps system sampling.
- Launched the compiled native application, captured its visible window and inspected [screenshot.png](screenshot.png). It displays actual CPU activity, memory/disk values and system processes. The screenshot is not a design mockup.

## Toolchain and execution environment

Command Line Tools 6.3.3 ships Swift Testing outside SwiftPM's default framework path. `scripts/test.sh` discovers the selected developer directory and supplies framework plus runtime search paths when needed. This CLT Testing framework was built for macOS 14; tests on this setup require macOS 14+, although the application targets macOS 13+. The linker emits a test-only minimum deployment warning for this difference.

The Codex shell sandbox blocked SwiftPM's nested manifest sandbox and denied the `ps` system read. Local verification therefore used `--disable-sandbox` for SwiftPM and ran the actual monitoring test in the permitted host environment. Normal user terminal execution does not need the Codex sandbox workaround.

UI screenshot verification covers the Overview screen. The task execution, stopping, concurrency and log behavior were exercised through the actual core runner; no automated accessibility test of the confirmation sheet is claimed. Logs have no disk quota, and stopping a script does not guarantee stopping all descendant processes. The bundle has no distribution signature or notarization.

## UI privacy revision

The sidebar footer now displays `macOS · Local device` and does not read or expose the hostname. Sidebar navigation buttons disable focus effects; the screenshot was recaptured from the rebuilt application with real metrics and no red focus highlight. Debug and Release application builds both passed after this UI-only change; the local bundle was rebuilt. Image pixels were not edited.
