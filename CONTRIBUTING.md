# Contributing to GitHubNotifier

Thank you for your interest in contributing to GitHubNotifier! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style Guidelines](#code-style-guidelines)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

Please be respectful and constructive in all interactions. We welcome contributors of all experience levels and backgrounds.

## Getting Started

### Prerequisites

- macOS 15.0 or later
- Swift 6
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) - `brew install swiftformat`
- [SwiftLint](https://github.com/realm/SwiftLint) - `brew install swiftlint`

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/GitHubNotifier.git
   cd GitHubNotifier
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/samzong/GitHubNotifier.git
   ```

## Development Setup

### Building the Project

```bash
# Build debug version
make build

# Build release version
make build-release

# Build and run for development
make run

# Install to ~/Applications
make install-app
```

### Code Quality Commands

```bash
# Format code with SwiftFormat
make format

# Check formatting (CI mode)
make format-check

# Run SwiftLint
make lint

# Run SwiftLint with auto-fix
make lint-fix

# Run all checks (format + lint)
make check
```

**Important**: Always run `make check` before submitting a pull request.

## Code Style Guidelines

### Language Requirements

**All code comments, documentation, and commit messages MUST be in English.**

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes/Structs | PascalCase | `NotificationService` |
| Methods/Properties | camelCase | `fetchNotifications()` |
| Constants | camelCase | `let maxRetries = 3` |
| Enum cases | camelCase | `case pullRequest` |

### Swift 6 Concurrency

This project uses Swift 6 strict concurrency. Key patterns to follow:

1. **Sendable conformance**: Classes used across actor boundaries must be `Sendable`:
   ```swift
   final class GitHubAPI: Sendable {
       private let token: String  // Must be `let`, not `var`
   }
   ```

2. **MainActor isolation**: UI-related services use `@MainActor`:
   ```swift
   @Observable
   @MainActor
   class NotificationService { ... }
   ```

3. **Observable pattern**: Use `@Observable` macro (not `ObservableObject/@Published`):
   ```swift
   @Observable
   class MyService {
       var value: String = ""  // No @Published needed
   }
   ```

### Code Formatting

- Use SwiftFormat with the project's `.swiftformat` configuration
- Run `make format` before committing
- CI will fail if code is not properly formatted

## Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification with [gitmoji](https://gitmoji.dev/).

### Format

```
<emoji> <type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types and Emojis

| Type | Emoji | Description |
|------|-------|-------------|
| feat | :sparkles: | New feature |
| fix | :bug: | Bug fix |
| docs | :memo: | Documentation |
| style | :lipstick: | UI/style changes |
| refactor | :recycle: | Code refactoring |
| perf | :zap: | Performance improvement |
| test | :white_check_mark: | Tests |
| build | :construction_worker: | Build system |
| ci | :green_heart: | CI configuration |
| chore | :wrench: | Maintenance |

### Examples

```
:sparkles: feat(notifications): add support for release notifications
:bug: fix(api): handle rate limit errors gracefully
:recycle: refactor(services): extract common API logic
:memo: docs: update README with new features
```

## Pull Request Process

### Before Submitting

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks**:
   ```bash
   make check
   ```

3. **Test your changes**:
   - Build and run the app: `make run`
   - Verify the feature works as expected
   - Check for any regressions

### Creating the PR

1. Push your branch to your fork:
   ```bash
   git push origin your-feature-branch
   ```

2. Open a Pull Request on GitHub

3. Fill in the PR template with:
   - Clear description of the changes
   - Screenshots/GIFs for UI changes
   - Related issue numbers (if any)

### PR Requirements

- [ ] Code follows the project's style guidelines
- [ ] All checks pass (`make check`)
- [ ] Commits follow the commit message guidelines
- [ ] Documentation is updated if needed
- [ ] No unnecessary files are included

### Review Process

- PRs require at least one approval before merging
- Address review feedback promptly
- Keep PRs focused and reasonably sized

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Environment**: macOS version, app version
2. **Steps to reproduce**: Clear, numbered steps
3. **Expected behavior**: What you expected to happen
4. **Actual behavior**: What actually happened
5. **Screenshots**: If applicable
6. **Logs**: Any relevant error messages

### Feature Requests

For feature requests, please describe:

1. **Problem**: What problem does this solve?
2. **Solution**: Your proposed solution
3. **Alternatives**: Any alternatives you've considered
4. **Context**: Additional context or screenshots

## Questions?

If you have questions, feel free to:

- Open a [Issue](https://github.com/samzong/GitHubNotifier/issues)
- Create an issue with the `question` label

Thank you for contributing!
