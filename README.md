# oh-my-agentpack

**agent 无关**的 CLI/MCP 与全局 skills 的复用安装清单与追溯记录。

与 [pi-PackgeManager](https://github.com/RoyougiShiki/pi-PackgeManager) 并列：那边管 **pi 专属**资产（pi-web、扩展、pi 配置模板），这边管**任何 agent 都能用**的通用资产（skills、codebase-mcp、opencli、mineru 等）。

## 定位

| 资产 | 归属 |
|------|------|
| 全局 skills：pdf-converter / opencli / lark-cli | **本仓库**（vendor 进 `skills/`，记录上游地址） |
| 全局 skills：mattpocock | **不在本仓库**（`type=upstream`：装时从上游取，见「上游型技能」一节） |
| 通用 CLI/MCP（codebase-memory-mcp / opencli / mineru-open-api / lark-cli） | **本仓库**（清单记录安装方式 + 当前版本） |
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
./install.sh                 # 同步 skills + 装缺失 CLI
./install.sh --skills-only   # 只同步 skills
./install.sh --yes           # 不提问，全按 manifest 走（无人值守）
./install.sh --help
```

安装后：
- skills 同步到 `~/.agents/skills/`（该目录是指向 Windows 侧的 symlink，物理位置 `/mnt/c/Users/h/.agents/skills/`，不动的项保留）
- 缺失的 CLI 自动安装（已装的只做版本检测）
- 当前版本写回 `manifest.json`（git 提交后形成追溯历史）

## 版本策略

- **CLI/MCP：一律 `latest`，不固定版本**（opencli、mineru、codebase-mcp 都无锁定必要）
- **`installedVersion` 记录"当前实际使用版本"**：每次 `install.sh` 检测并写回 manifest，配合 git history 可追溯"某时间点用的是哪个版本"
- **skills 两种来源**（manifest 每个条目的 `type`）：
  - `vendor` / `local`：复印件存在本仓 `skills/<名>/`，同步时**整目录覆盖**目标同名目录
  - `upstream`：仓内**不留复印件**，装时从上游按 `ref` 取；只覆盖本次取到的技能目录，目标里其余内容（含集合根目录下手写的 `README.md`）一律不写不删
- **每个条目记录上游仓库地址 + 版本 + 裁剪说明**，需要迭代时从上游拉取对比

## 上游型技能（type=upstream）

目前只有 `mattpocock` 一项。作者 Matt Pocock 在 [mattpocock/skills](https://github.com/mattpocock/skills) 活跃地改这套技能，且**他自己的安装说明就是"装时从上游取，重跑一次命令即更新"**（上游 README「Installation」一节），没有建议过把文件复制进第三方仓库冻结。所以本仓不再存复印件——存了就会分叉，而分叉的复印件一旦被 `install.sh` 推出去，就是把用户的新版本盖回旧版本。

manifest 字段：

| 字段 | 作用 |
|------|------|
| `source` | 上游地址 |
| `versionPolicy` | `pinned` = 取 `ref` 那个固定 commit；`latest` = 取上游默认分支最新 |
| `ref` / `installedRef` | 要取的 commit / 上次实际取到的 commit（脚本写回，追溯用） |
| `buckets` | 上游里要取的子目录，摊平到 `~/.agents/skills/<名>/<技能>/` |
| `exclude` | 桶里点名不要的技能；**改这张表要用户确认** |

`install.sh` 交互运行时会把「当前锁哪个 commit、取哪些桶」念出来并问一句；`--yes` 或非终端环境下静默按 manifest 走。`--skills-only` 只同步 skills 不碰 CLI。

**为什么 `ref` 记 commit 而不是 tag**（实测，不是猜测）：最新标签 `v1.3.1`(24fe0ef) 比 `main`(49dd158) **少 46 个提交**。把 `ref` 写成 tag 就是一次倒退——实测钉 `v1.1.0` 会取到 13 只，里面缺 `retro`/`wait-what`/`writing-for-agents`，还多出上游早已删掉的 `resolving-merge-conflicts`、`writing-great-skills`。

**升版流程**：把 `ref` 改成新的 commit（或 `versionPolicy` 设 `latest` 跑一次，脚本会把实际 commit 写回 `installedRef`），跑 `install.sh --skills-only`，然后读上游 `CHANGELOG.md` 看这一版动了什么——作者会改名和挪桶（`to-prd`→`to-spec`、`to-issues`→`to-tickets`、`CONTEXT.md`→`GLOSSARY.md` 都发生过），挪桶时脚本会以「上游没有桶 skills/xxx」停下且不改动目标。

**取法为什么是 tarball 而不是 `git clone`**：本机实测 WSL 和 Windows 侧 `git clone https://github.com/...` 连续 3 次全失败（`GnuTLS recv error (-110)` / `443 连不上` / `Connection was reset`），而 `api.github.com` 与 `codeload.github.com` 用 curl 稳定可通。这与 `manifest.json` 里 lark-cli 当年记下的「WSL 直连 GitHub 不稳定」是同一件事。所以 GitHub 源走「api 解析 commit → codeload 取 tar.gz」，非 GitHub 源仍退回 `git clone`。

**失败不会清空你的技能**：脚本先把上游内容全部取齐并校验（桶存在、`SKILL.md` 存在、数量 > 0），全部通过才开始写目标。取不到就打印 `✗ ……已停止 —— 目标 …… 一个字没改` 并保留原有文件。

## 可选安装（不同机器装不同部分）

manifest.json 中每个 CLI 和 skill 都支持 `enabled` 字段（默认 `true`）：

```json
"opencli": {
  ...
  "enabled": false   // 本机不需要浏览器自动化：不装 CLI、不同步其 skills
}
```

新机器 clone 后，按需把不需要的项标记 `enabled: false`（只改本机副本，不提交或提交均可），再跑 `./install.sh`，被禁用的项会跳过并打印提示。

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
      "type": "upstream",                              // 仓内不存复印件
      "source": "https://github.com/mattpocock/skills", // 上游地址
      "versionPolicy": "pinned",                        // pinned | latest
      "ref": "49dd158",                                 // 取哪个 commit
      "installedRef": "49dd158",                        // 上次实际取到的（脚本写回）
      "buckets": ["engineering", "productivity"],       // 取上游哪些子目录
      "exclude": ["tdd", "code-review"],                // 桶里点名不要的
      "depends": []                                     // 依赖的 CLI
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

### Skills

| 条目 | type | 来源 | 说明 |
|------|------|------|------|
| `mattpocock` | **upstream** | [mattpocock/skills](https://github.com/mattpocock/skills) @ `49dd158`（main，2026-10-09） | 仓内无复印件。取 engineering + productivity 两桶，`exclude` 表点掉 13 只 → 实装 14 只 |
| `pdf-converter` | vendor | [tanis90/pdf-converter-mineru](https://github.com/tanis90/pdf-converter-mineru) | 无裁剪 |
| `opencli` | vendor | npm `@jackwener/opencli` skills/ 目录 | 去 `opencli-` 前缀，仅保留 6 项 |
| `lark-cli` | vendor | [larksuite/cli](https://github.com/larksuite/cli) skills/ 目录 | 27 项全集 |

`goal-draft`（原 `type=local`）于 2026-10-11 移除：`~/.agents/skills/` 里从来不曾出现它，除 manifest 自身外无任何引用，实际未在用。要找回原文：`git show 6e5fdac:skills/goal-draft/SKILL.md`。

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
