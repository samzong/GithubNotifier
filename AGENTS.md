# AGENTS.md

## Scope

These instructions apply to the whole `Branchlight` repository.

This is a Swift Package Manager macOS app. Treat the current source, `Package.swift`, `Makefile`, and workflow files as the source of truth. If older docs disagree with those files, follow the code/config first and update docs separately when asked.

## Project Shape

- Product: lightweight macOS 15+ menu bar app for GitHub notifications, issues, pull requests, activities, and saved searches.
- Package: Swift tools 6.0 with strict concurrency enabled on both app targets.
- Targets:
  - `GitHubNotifierCore`: core models, auth, GitHub REST/GraphQL clients, services, rule engine, storage, utilities.
  - `GitHubNotifier`: SwiftUI/AppKit executable target with Sparkle updates, Kingfisher, menu bar UI, settings, app resources, and `Info.plist`.
  - `GitHubNotifierTests`: XCTest target for app-level behavior.
- Main paths:
  - `Sources/GitHubNotifierCore/**` for reusable logic and GitHub API behavior.
  - `Sources/GitHubNotifier/**` for app composition, windows, settings, menu bar UI, and resources.
  - `Tests/GitHubNotifierTests/**` for tests.
  - `Scripts/**` and `Makefile` for local build, packaging, release, and Homebrew update automation.

## Commands

Prefer the project Make targets over ad hoc commands:

- `make build`: debug build and package the app for the current architecture.
- `make run`: compile and run the debug app via `Scripts/compile_and_run.sh`.
- `make test`: run all Swift tests.
- `make lint`: run SwiftLint on `Sources`.
- `make lint-fix`: run SwiftLint autocorrect on `Sources`.
- `make format`: format `Sources` with SwiftFormat and `.swiftformat`.
- `make format-check`: check SwiftFormat formatting without rewriting.
- `make check`: run `lint-fix`, `lint`, `format`, then `format-check`; this can modify files.
- `make dmg`: build release DMGs for `x86_64` and `arm64`.
- `make install`: build release and install to `~/Applications/GitHubNotifier.app`.
- `make clean`: clean SwiftPM and `.build`.

Before using any less common CLI flag, verify it with `--help` or official documentation.

## Coding Rules

- Write code, comments, commit messages, PR text, and tracked docs in English unless the user explicitly asks otherwise.
- Keep changes small and targeted. Do not introduce new architecture layers unless the existing code needs them.
- Follow Swift 6 strict concurrency. Preserve actor boundaries and `Sendable` expectations.
- UI state and app-facing services commonly use `@Observable` and `@MainActor`; keep that pattern unless there is a concrete reason to change it.
- Keep secrets in Keychain-related paths. Do not log tokens or persist GitHub credentials outside the existing secure storage approach.
- REST notification behavior belongs in `GitHubAPI`; richer issue/PR detail and search behavior belongs in GraphQL/client/service code. Do not mix protocols casually.
- For UI work, preserve the menu-bar-first workflow and keep transient flows quick and lightweight.
- Use existing localization resources under `Resources/en.lproj` and `Resources/zh-Hans.lproj` for user-visible strings.
- Use SwiftFormat and SwiftLint configs in this repo. Do not hand-format against a different style.

## Verification

- For core/service changes: run `make test` at minimum.
- For formatting or style-sensitive changes: run `make format-check` and `make lint`. Use `make check` only when file rewriting is acceptable.
- For UI changes: run the app with `make run` and visually verify the affected window/menu behavior.
- For packaging/release changes: run the narrow script or Make target touched by the change; use `make dmg` only when the full release package path needs proof.
- Do not claim fixed, done, or passing unless the relevant command or runtime check was actually run. If verification was skipped, state that explicitly.

## Git and Releases

- Do not commit or push without explicit user approval.
- Before committing, inspect the staged diff and keep commits focused.
- Release workflow is tag-driven (`v*`) and builds/signs DMGs in GitHub Actions.
- Homebrew update automation depends on `GH_PAT` and `make update-homebrew`.
- Avoid changing release/signing/appcast behavior without verifying the corresponding workflow or script path.
