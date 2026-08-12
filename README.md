# oh-my-agentpack

**agent 无关**的 CLI/MCP 与全局 skills 的复用安装清单与追溯记录。

与 [pi-PackgeManager](https://github.com/RoyougiShiki/pi-PackgeManager) 并列：那边管 **pi 专属**资产（pi-web、扩展、pi 配置模板），这边管**任何 agent 都能用**的通用资产（skills、codebase-mcp、opencli、mineru 等）。

## 定位

| 资产 | 归属 |
|------|------|
| 全局 skills（mattpocock / pdf-converter / opencli） | **本仓库**（vendor 进 `skills/`，记录上游地址） |
| 通用 CLI/MCP（codebase-memory-mcp / opencli / mineru-open-api） | **本仓库**（清单记录安装方式 + 当前版本） |
| kb-access skill | ai-knowledge 仓库（symlink，本仓库不接管） |
| pi 扩展 / pi-web / pi 配置 | pi-PackgeManager |
| cliproxyapi / dotfiles / docker / WSL2 引导 | wsl2-dev-setup（环境层，暂不维护） |

**不负责：**
- pi 本体与 pi 扩展（见 pi-PackgeManager）
- 环境层（cliproxyapi / dotfiles / docker，见 wsl2-dev-setup）
- 个人知识库（见 ai-knowledge）

## 快速开始

```bash
git clone https://github.com/RoyougiShiki/oh-my-agentpack.git
cd oh-my-agentpack
./install.sh
```

安装后：
- skills 同步到 `~/.agents/skills/`（该目录是指向 Windows 侧的 symlink，物理位置 `/mnt/c/Users/h/.agents/skills/`，不动的项保留）
- 缺失的 CLI 自动安装（已装的只做版本检测）
- 当前版本写回 `manifest.json`（git 提交后形成追溯历史）

## 版本策略

- **CLI/MCP：一律 `latest`，不固定版本**（opencli、mineru、codebase-mcp 都无锁定必要）
- **`installedVersion` 记录"当前实际使用版本"**：每次 `install.sh` 检测并写回 manifest，配合 git history 可追溯"某时间点用的是哪个版本"
- **skills：vendor 进仓库**（`skills/` 为真源，可能有本地裁剪），每个条目记录**上游仓库地址 + 快照版本 + 裁剪说明**，需要迭代时从上游拉取对比

## manifest.json

唯一真源，驱动 install.sh。结构：

```json
{
  "cli": {
    "codebase-memory-mcp": {
      "type": "mcp",
      "install": "...",          // 安装命令
      "versionPolicy": "latest",
      "installedVersion": "1.8.6"  // 当前使用版本（追溯）
    }
  },
  "skills": {
    "mattpocock": {
      "type": "vendor",
      "source": "https://github.com/mattpocock/skills",  // 上游地址
      "sourceVersion": "v1.1.0",
      "localChanges": "裁剪说明",
      "depends": ["mineru-open-api"]  // 依赖的 CLI
    }
  }
}
```

## 当前清单

### CLI / MCP

| 名称 | 类型 | 当前版本 | 说明 |
|------|------|----------|------|
| codebase-memory-mcp | mcp | 0.6.1 | 代码记忆库 MCP |
| opencli | cli | 1.8.6 | 浏览器自动化 CLI |
| mineru-open-api | cli | v0.5.9 | MinerU 文档转换 API CLI（pdf-converter 依赖） |

### Skills（vendor，含裁剪）

| 目录 | 上游 | 本地变更 |
|------|------|----------|
| `skills/mattpocock/` | [mattpocock/skills](https://github.com/mattpocock/skills) v1.1.0 | 移除 grill-me / handoff |
| `skills/pdf-converter/` | [tanis90/pdf-converter-mineru](https://github.com/tanis90/pdf-converter-mineru) | 无 |
| `skills/opencli/` | npm `@jackwener/opencli` skills/ 目录 | 去 `opencli-` 前缀，仅保留 6 项 |

## 手工项（新机器 checklist）

1. opencli 浏览器扩展：Chrome Web Store 搜索 opencli（ID: `ildkmabpimmkaediidaifkhjpohdnifk`）
2. codebase-memory-mcp 的 MCP 服务器配置：pi 侧在 `~/.config/mcp/mcp.json`（由 pi-PackgeManager 模板生成）
3. `mineru-open-api auth`：如需 extract 模式（大文件/批处理）解锁

## 与其他仓库的关系

| 仓库 | 职责 |
|------|------|
| **oh-my-agentpack**（本仓库） | agent 无关的 skills + 通用 CLI/MCP 清单 |
| **pi-PackgeManager** | Pi 专属：pi-web + 扩展 + pi 配置模板 |
| **ai-knowledge** | 个人知识库 + kb-access skill |
| **wsl2-dev-setup** | 环境层：cliproxyapi + dotfiles + docker（简陋，暂不维护） |
