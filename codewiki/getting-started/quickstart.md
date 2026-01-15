# 快速开始

```text
# Related Code
- Package.swift
- Makefile
- Sources/GitHubNotifier/App/GitHubNotifierApp.swift
```

## 前置要求

- macOS 15.0+ (Sequoia)
- Xcode 16+ 或 Swift 6.0+ 工具链
- GitHub Personal Access Token (需要 `notifications` 和 `read:user` 权限)

## 构建与运行

### 1. 克隆仓库

```bash
git clone https://github.com/samzong/GitHubNotifier.git
cd GitHubNotifier
```

### 2. 构建应用

```bash
make build
```

预期输出:
```
🔨 Building GitHubNotifier (debug)...
✅ Build completed!
📍 Application: .build/arm64-apple-macosx/debug/GitHubNotifier.app
```

### 3. 运行应用

```bash
make run
```

或直接打开构建的 .app:
```bash
open .build/arm64-apple-macosx/debug/GitHubNotifier.app
```

### 4. 配置 Token

1. 点击菜单栏 GitHub 图标
2. 在欢迎界面点击 "配置 Token"
3. 粘贴你的 GitHub Personal Access Token
4. 点击保存

Token 将安全存储在 macOS Keychain 中。

## 生产构建

构建发布版本 DMG:

```bash
make dmg
```

输出:
- `.build/GitHubNotifier-x86_64.dmg` (Intel)
- `.build/GitHubNotifier-arm64.dmg` (Apple Silicon)

## 常用命令

| 命令 | 说明 |
|------|------|
| `make help` | 显示所有可用命令 |
| `make build` | 构建 debug 版本 |
| `make run` | 快速构建并运行 |
| `make lint` | 运行 SwiftLint 检查 |
| `make format` | 格式化代码 |
| `make clean` | 清理构建产物 |
| `make dmg` | 构建发布 DMG |
