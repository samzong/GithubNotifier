import { withMermaid } from "vitepress-plugin-mermaid"
import sidebar from "./sidebar.mjs"

export default withMermaid({
  title: 'GitHubNotifier',
  description: 'macOS 菜单栏 GitHub 通知中心 - 代码优先文档',
  cleanUrls: true,
  lang: 'zh-CN',
  themeConfig: {
    nav: [
      { text: "概览", link: "/overview" },
      { text: "快速开始", link: "/getting-started/quickstart" },
      { text: "架构", link: "/architecture/overview" }
    ],
    sidebar,
    outline: {
      level: [2, 3, 4]
    },
    outlineTitle: '本页目录',
    lastUpdatedText: '最后更新',
    docFooter: {
      prev: '上一页',
      next: '下一页'
    },
    search: {
      provider: 'local',
      options: {
        translations: {
          button: {
            buttonText: '搜索文档',
            buttonAriaLabel: '搜索文档'
          },
          modal: {
            noResultsText: '未找到相关结果',
            resetButtonTitle: '清除查询条件',
            footer: {
              selectText: '选择',
              navigateText: '切换'
            }
          }
        }
      }
    }
  },
  mermaid: {}
})
