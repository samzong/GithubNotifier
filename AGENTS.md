# AGENTS.md

## Scope

These instructions apply to the whole `Branchlight` repository.

`Branchlight` is the public app, repository, and release name. The Swift package,
executable, bundle identifier, and several source paths still use
`GitHubNotifier`; do not rename those without a deliberate release/migration
plan.

Treat the current source, `Package.swift`, `Makefile`, scripts, workflows, and
`Info.plist` as the source of truth. If older docs disagree with code or config,
follow the code/config first and update docs separately when asked.

## Project Shape

- Product: lightweight macOS 15+ menu bar app for GitHub notifications, issues, pull requests, activities, and saved searches.
- App model: `LSUIElement` accessory app with a SwiftUI `MenuBarExtra`, a native `Settings` scene, and auxiliary window surfaces for saved-search management.
- Package: Swift tools 6.0, `.macOS(.v15)`, with strict concurrency enabled on the core and app targets.
- Dependencies: Sparkle for updates, Kingfisher for remote images.
- Targets:
  - `GitHubNotifierCore`: core models, auth, GitHub REST/GraphQL clients, services, rule engine, storage, utilities.
  - `GitHubNotifier`: SwiftUI/AppKit executable target with Sparkle updates, Kingfisher, menu bar UI, settings, app resources, and `Info.plist`.
  - `GitHubNotifierTests`: XCTest target for app-level behavior.
- Runtime boundaries:
  - GitHub OAuth device flow and token storage live in `AuthStore` and Keychain-related code.
  - REST notification fetch/mark-read behavior belongs in `GitHubAPI`.
  - Rich issue/PR details, activity, and saved-search data belong in `GitHubGraphQLClient` and service code.
  - Local notifications are owned by `NotificationManager`.
- Main paths:
  - `Sources/GitHubNotifierCore/**` for reusable logic and GitHub API behavior.
  - `Sources/GitHubNotifier/**` for app composition, windows, settings, menu bar UI, and resources.
  - `Tests/GitHubNotifierTests/**` for tests.
  - `Scripts/**` and `Makefile` for local build, packaging, release, and Homebrew update automation.
  - `.github/workflows/**` for release, Homebrew, and docs automation.

## Codex Plugin Routing

This is a macOS app repo. Before starting macOS app work, check whether the
Codex `Build macOS Apps` plugin has a matching skill. If a matching skill
exists, read that skill's `SKILL.md` and follow it before using ad hoc commands
or guidance.

Prefer the narrowest relevant skill:

- `swiftpm-macos`: inspect `Package.swift`, build, run, and test SwiftPM targets.
- `build-run-debug`: build, launch, and diagnose compile, link, startup, or desktop runtime failures.
- `swiftui-patterns`: design or change `MenuBarExtra`, `Settings`, `NavigationSplitView`, toolbars, commands, and macOS SwiftUI structure.
- `view-refactor`: split oversized SwiftUI views or scenes while keeping behavior stable.
- `window-management`: choose and tune `Window`, `WindowGroup`, sizing, activation, restoration, and window lifecycle.
- `appkit-interop`: use narrow AppKit bridges for panels, `NSApplication`, `NSWorkspace`, windows, or responder-chain behavior that SwiftUI cannot model cleanly.
- `liquid-glass`: adopt or review macOS 26+ Liquid Glass, materials, and related UI APIs.
- `telemetry`: add or verify `Logger` / unified logging for runtime behavior.
- `test-triage`: narrow failing SwiftPM or macOS tests.
- `signing-entitlements`: inspect Keychain, launch-at-login, codesigning, Gatekeeper, entitlement, or trust-policy issues.
- `packaging-notarization`: validate app bundles, DMGs, Sparkle/appcast, notarization readiness, and distribution failures.

## Commands

Prefer the project Make targets over ad hoc commands:

- `make version`: show resolved version, marketing version, build number, and git commit.
- `make build`: debug build and package the app for the current architecture.
- `make run`: compile and run the debug app via `Scripts/compile_and_run.sh`.
- `make test`: run all Swift tests.
- `make lint`: run SwiftLint on `Sources`.
- `make lint-fix`: run SwiftLint autocorrect on `Sources`.
- `make format`: format `Sources` with SwiftFormat and `.swiftformat`.
- `make format-check`: check SwiftFormat formatting without rewriting.
- `make check`: run `lint-fix`, `lint`, `format`, then `format-check`; this can modify files.
- `make dmg`: build release DMGs for `x86_64` and `arm64`.
- `make install`: build release and install to `~/Applications/Branchlight.app`.
- `make clean`: clean SwiftPM and `.build`.
- `make update-homebrew`: update the Homebrew tap automation; requires `GH_PAT`.

Before using any less common CLI flag, verify it with `--help` or official documentation.

## Coding Rules

- Write code, comments, commit messages, PR text, and tracked docs in English unless the user explicitly asks otherwise.
- Keep changes small and targeted. Do not introduce new architecture layers unless the existing code needs them.
- Follow Swift 6 strict concurrency. Preserve actor boundaries and `Sendable` expectations.
- UI state and app-facing services commonly use `@Observable` and `@MainActor`; keep that pattern unless there is a concrete reason to change it.
- Use `@AppStorage` for durable preferences and `@SceneStorage` only for scene/window-scoped ephemeral state.
- Keep secrets in Keychain-related paths. Do not log tokens or persist GitHub credentials outside the existing secure storage approach.
- REST notification behavior belongs in `GitHubAPI`; richer issue/PR detail and search behavior belongs in GraphQL/client/service code. Do not mix protocols casually.
- For UI work, preserve the menu-bar-first workflow and keep transient flows quick and lightweight.
- Model desktop surfaces explicitly: `MenuBarExtra`, `Settings`, and auxiliary windows should have clear scene/window ownership.
- Prefer SwiftUI scene/window APIs before AppKit. When AppKit is needed, keep the bridge narrow and local to the platform behavior.
- Split oversized SwiftUI views before adding more state, toolbar logic, or child flows. Prefer focused subviews with explicit inputs and actions.
- Use existing localization resources under `Resources/en.lproj` and `Resources/zh-Hans.lproj` for user-visible strings. Do not add hardcoded visible UI strings in Swift unless they are temporary debug-only text.
- Use SwiftFormat and SwiftLint configs in this repo. Do not hand-format against a different style.

## Verification

- For documentation-only changes: inspect the rendered diff; tests are not required unless the docs describe behavior that should be verified.
- For core/service changes: run `make test` at minimum.
- For GitHub API, auth, refresh, rule, saved-search, or notification behavior: prefer deterministic tests or a stubbed harness over live-network-only proof.
- For formatting or style-sensitive changes: run `make format-check` and `make lint`. Use `make check` only when file rewriting is acceptable.
- For UI changes: run the app with `make run` and visually verify the affected menu bar, settings, or window behavior.
- For window/AppKit changes: verify behavior in a real `.app` bundle, not only with compile checks.
- For signing, entitlement, or trust-policy changes: inspect the built artifact with `codesign`, `spctl`, or `plutil` as appropriate.
- For packaging/release changes: run the narrow script or Make target touched by the change; use `make dmg` only when the full release package path needs proof.
- Do not claim fixed, done, or passing unless the relevant command or runtime check was actually run. If verification was skipped, state that explicitly.

## Git and Releases

- Do not commit or push without explicit user approval.
- Before committing, inspect the staged diff, keep commits focused, and use signed-off commits.
- Release workflow is tag-driven (`v*`) and builds/signs x86_64 and arm64 DMGs in GitHub Actions.
- Sparkle release behavior depends on `SUPublicEDKey`, `SPARKLE_ED_KEY`, generated appcast output, and the release workflow.
- Homebrew update automation depends on `GH_PAT`, the release DMGs, and `make update-homebrew`.
- The `idoc` workflow publishes docs from `main`; keep README-facing product names aligned with Branchlight.
- Avoid changing release/signing/appcast behavior without verifying the corresponding workflow or script path.
