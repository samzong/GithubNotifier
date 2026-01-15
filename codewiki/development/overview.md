# 开发指南

```text
# Related Code
- Makefile
- .swiftlint.yml
- .swiftformat
- Scripts/
```

## 本地开发流程

### 推荐工作流

```bash
# 1. 启动开发模式 (自动编译运行)
make run

# 2. 修改代码后重新运行
make run

# 3. 提交前检查
make check  # 运行 lint + format
```

### 代码规范

项目使用 SwiftLint 和 SwiftFormat 保证代码一致性:

```bash
# 检查代码规范
make lint

# 自动修复
make lint-fix

# 格式化代码
make format
```

## 项目结构

```
Sources/
├── GitHubNotifierCore/       # 核心业务逻辑 (无 UI)
│   ├── Models/               # 数据模型
│   ├── Services/             # 服务层
│   └── Utils/                # 工具类
└── GitHubNotifier/           # UI 层
    ├── App/                  # 应用入口
    ├── Views/                # SwiftUI 视图
    │   ├── MenuBar/          # 菜单栏组件
    │   ├── Notifications/    # 通知列表
    │   ├── Activity/         # 活动列表
    │   ├── Search/           # 搜索功能
    │   ├── Settings/         # 设置页面
    │   └── Components/       # 通用组件
    ├── Utils/                # UI 工具
    └── Resources/            # 资源文件
```

## 调试技巧

### 1. 查看网络请求

在 `GitHubAPI.swift` 和 `GitHubGraphQLClient.swift` 中添加断点:

```swift
// GitHubAPI.swift:73 - REST 请求
private func makeRequest<T: Decodable>(...) async throws -> T

// GitHubGraphQLClient.swift - GraphQL 请求
func execute<T: Decodable>(...) async throws -> T
```

### 2. 模拟通知

在 Settings → About 中有 "发送测试通知" 按钮，无需真实数据即可测试通知功能。

### 3. 清除缓存

删除 Token 后重新登录可清除所有缓存状态:
- Settings → Account → 清除 Token

## 常见问题

### 构建失败: missing required module

```bash
swift package resolve
make clean && make build
```

### Token 无效

确保 Token 具有以下权限:
- `notifications` - 读取通知
- `read:user` - 读取用户信息
- `repo` - 读取私有仓库 (可选)

### 自动更新不工作

Sparkle 需要签名的应用包。本地 debug 构建不支持自动更新，需使用 `make dmg` 构建发布版本。

## 测试策略

当前项目暂无自动化测试。建议优先添加:

1. **Service 层单元测试**: 测试 `NotificationService`、`SearchService` 的业务逻辑
2. **API Mock 测试**: 使用 URLProtocol mock 测试 API 调用
3. **UI 快照测试**: 使用 swift-snapshot-testing 验证 UI 渲染
