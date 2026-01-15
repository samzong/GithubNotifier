# 通知数据流

```text
# Related Code
- Sources/GitHubNotifierCore/Services/NotificationService.swift
- Sources/GitHubNotifierCore/Services/GitHubAPI.swift
- Sources/GitHubNotifierCore/Services/GitHubGraphQLClient.swift
- Sources/GitHubNotifierCore/Services/NotificationManager.swift
```

## 完整数据流

```mermaid
flowchart TB
    subgraph User[用户]
        Click[点击菜单栏图标]
        View[查看通知]
        Action[标记已读]
    end

    subgraph UI[UI Layer]
        MenuBarView
        NotificationListView
        NotificationRowView
    end

    subgraph Service[Service Layer]
        NS[NotificationService]
        NM[NotificationManager]
    end

    subgraph API[API Layer]
        REST[GitHubAPI]
        GQL[GitHubGraphQLClient]
    end

    subgraph External[外部系统]
        GitHubAPI[GitHub REST API]
        GitHubGQL[GitHub GraphQL API]
        UNC[UNUserNotificationCenter]
    end

    Click --> MenuBarView
    MenuBarView --> NS
    NS --> REST
    REST --> GitHubAPI
    GitHubAPI --> REST
    REST --> NS

    NS --> GQL
    GQL --> GitHubGQL
    GitHubGQL --> GQL
    GQL --> NS

    NS --> NotificationListView
    NotificationListView --> NotificationRowView
    NotificationRowView --> View

    NS --> NM
    NM --> UNC

    Action --> NS
    NS --> REST
```

## 启动流程

```mermaid
sequenceDiagram
    participant App as GitHubNotifierApp
    participant NS as NotificationService
    participant KC as KeychainHelper
    participant REST as GitHubAPI
    participant GQL as GitHubGraphQLClient

    App->>NS: init(token:)
    NS->>KC: getToken()
    KC-->>NS: token

    alt Token 存在
        NS->>REST: init(token:)
        NS->>GQL: init(token:)
        NS->>NS: startAutoRefreshIfNeeded()
        NS->>NS: fetchNotifications()
    else Token 不存在
        NS-->>App: 显示 WelcomeView
    end
```

## 通知获取流程

```mermaid
sequenceDiagram
    participant UI as NotificationListView
    participant NS as NotificationService
    participant REST as GitHubAPI
    participant GQL as GitHubGraphQLClient
    participant Cache as StateCache

    UI->>NS: 触发刷新
    NS->>NS: isLoading = true

    NS->>REST: fetchNotifications()
    REST-->>NS: [GitHubNotification]

    loop 每个通知
        NS->>Cache: 检查缓存
        alt 缓存命中
            Cache-->>NS: NotificationDetails
        else 缓存未命中
            NS->>GQL: fetchNotificationDetails(items)
            GQL-->>NS: [NotificationDetails]
            NS->>Cache: 更新缓存
        end
    end

    NS->>NS: notifications = result
    NS->>NS: isLoading = false
    NS-->>UI: @Published 触发更新
```

## 新通知检测

```mermaid
flowchart LR
    subgraph Detection[检测逻辑]
        A[获取新通知列表] --> B[提取 ID 集合]
        B --> C[与上次 ID 对比]
        C --> D{有新 ID?}
        D -->|是| E[筛选新通知]
        D -->|否| F[跳过]
        E --> G[发送系统通知]
    end

    subgraph State[状态维护]
        H[previousNotificationIds]
        G --> I[更新 previousNotificationIds]
    end
```

首次加载不触发系统通知，避免打开应用时通知轰炸。

## 标记已读流程

```mermaid
sequenceDiagram
    participant User
    participant UI as NotificationRowView
    participant NS as NotificationService
    participant REST as GitHubAPI
    participant GitHub

    User->>UI: 点击标记已读
    UI->>NS: markAsRead(notification)
    NS->>NS: 乐观更新 UI
    NS->>REST: markNotificationAsRead(threadId)
    REST->>GitHub: PATCH /notifications/threads/{id}

    alt 成功
        GitHub-->>REST: 200 OK
        REST-->>NS: 成功
    else 失败
        GitHub-->>REST: Error
        REST-->>NS: 抛出错误
        NS->>NS: 回滚 UI 状态
        NS->>UI: 显示错误
    end
```

## 缓存策略

```mermaid
graph TB
    subgraph CacheTypes[缓存类型]
        PRC[prStateCache<br/>PR 状态]
        ISC[issueStateCache<br/>Issue 状态]
        DC[detailsCache<br/>完整详情]
    end

    subgraph Lifecycle[生命周期]
        Create[通知详情加载时创建]
        Read[UI 渲染时读取]
        Prune[定时清理过期条目]
        Clear[Token 清除时全部清空]
    end

    Create --> PRC
    Create --> ISC
    Create --> DC

    PRC --> Read
    ISC --> Read
    DC --> Read

    Prune --> PRC
    Prune --> ISC
    Prune --> DC

    Clear --> PRC
    Clear --> ISC
    Clear --> DC
```

缓存 Key 格式: `{owner}/{repo}/{type}/{number}`

## 自动刷新

```mermaid
stateDiagram-v2
    [*] --> Stopped: 初始状态

    Stopped --> Running: startAutoRefresh()
    Running --> Stopped: stopAutoRefresh()
    Running --> Running: 每 30s 触发

    state Running {
        [*] --> Wait
        Wait --> Fetch: 定时器触发
        Fetch --> Wait: 完成
    }
```

刷新间隔可在 Settings → General 中配置。
