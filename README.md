# GitHubNotifier
    
<div align="center">
  <img src="Sources/GitHubNotifier/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" alt="GitHubNotifier" width="128" />
  <br />
  <div id="download-section" style="margin: 20px 0;">
    <a href="https://github.com/samzong/GitHubNotifier/releases/latest" style="text-decoration: none;">
      <img src="https://img.shields.io/badge/⬇%20Download%20for%20macOS-28a745?style=for-the-badge&labelColor=28a745" alt="Download" />
    </a>
  </div>
  <p>A lightweight macOS menubar hub for your GitHub works.</p>
  <p>
    <a href="https://github.com/samzong/GitHubNotifier/releases"><img src="https://img.shields.io/github/v/release/samzong/GitHubNotifier" alt="Release" /></a>
    <a href="https://github.com/samzong/GitHubNotifier/blob/main/LICENSE"><img src="https://img.shields.io/github/license/samzong/GitHubNotifier" alt="License" /></a>
    <a href="https://deepwiki.com/samzong/GitHubNotifier"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
  </p>
</div>

## Screenshots

<p align="center">
  <img src="docs/images/notifications.png" width="45%" />
  <img src="docs/images/activities.png" width="45%" />
</p>

## Design Principles

- Menubar is the single entry point and attention anchor
- 30-second rule: core flows should finish within half a minute
- Keep it lightweight: do triage here, deep work in GitHub
- Use-and-go: quick actions in a transient window, not a permanent workspace

## Current Capabilities

- Menubar-first workflow with configurable Notifications, Activities, and Search tabs
- GitHub OAuth device flow sign-in
- Unread GitHub notifications with issue/PR grouping, mark-as-read actions, and system notifications
- Activities view powered by GitHub Search for open issues/PRs you created, are assigned to, are mentioned in, or were requested to review
- Saved searches for issues, PRs, and repositories, with optional pinned searches in the menu bar
- Notification rules for matching repository, organization, notification type, or reason, with mark-as-read and suppress-notification actions
- Status cache and CI check summary in list items
- Auto-updates via Sparkle
- i18n support (EN / zh-Hans)

## Next Up

- Activity and search workflow refinements
- More rule actions and notification controls

## Requirements

- macOS 15+
