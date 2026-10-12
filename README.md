# oh-my-agentpack

**agent 无关**的 CLI/MCP 与全局 skills 的复用安装清单与追溯记录。

与 [pi-PackgeManager](https://github.com/RoyougiShiki/pi-PackgeManager) 并列：那边管 **pi 专属**资产（pi-web、扩展、pi 配置模板），这边管**任何 agent 都能用**的通用资产（skills、codebase-mcp、opencli、mineru 等）。

## 定位

| 资产 | 归属 |
|------|------|
| 上游 skills：mattpocock / lark-cli / opencli / pdf-converter | **不在本仓库**（`type=upstream`：装时从上游取，见「上游型技能」一节） |
| 自写 skills：skill-creator / lead-subagent-collaboration | **本仓库**（`type=local`，仓内 `skills/` 即真源） |
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
./install.sh                 # 同步 skills + 装缺失 CLI（skills 会逐项问你要装什么）
./install.sh --skills-only   # 只同步 skills
./install.sh --yes           # 不提问，全按 manifest 记的默认值走（无人值守）
./install.sh --help
```

安装后：
- skills 同步到 `~/.agents/skills/`（该目录是指向 Windows 侧的 symlink，物理位置 `/mnt/c/Users/h/.agents/skills/`，没被本次清单管起来的项保留）
- 缺失的 CLI 自动安装（已装的只做版本检测）
- 取到的版本写回 `manifest.json`（git 提交后形成追溯历史）

## 版本策略

- **CLI/MCP：一律 `latest`，不固定版本**（opencli、mineru、codebase-mcp 都无锁定必要）
- **`installedVersion` 记录"当前实际使用版本"**：每次 `install.sh` 检测并写回 manifest，配合 git history 可追溯"某时间点用的是哪个版本"
- **skills 两种来源**（manifest 每个条目的 `type`）：
  - `local` / `vendor`：复印件存在本仓 `skills/<名>/`，同步时**整目录覆盖**目标同名目录（`local` = 本仓即真源，没有上游可跟）
  - `upstream`：仓内**不留复印件**，装时从上游取；只覆盖本次取到的技能目录，目标里其余内容（含集合根目录下手写的 `README.md`）一律不写不删
- **manifest 记的是默认值，不是账本**：`ref` / `installedRef` 是「上次用的版本」，`buckets` / `exclude` / `include` 是「上次选中的范围」。所以本仓**不写「实装几只」「装了哪些」这类数量与清单**——每次安装都会重新问，每台机器选的都不同，写死的那一刻就开始过期。

## 上游型技能（type=upstream）

`mattpocock` / `lark-cli` / `opencli` / `pdf-converter` 都不存复印件。理由对四者都成立：作者们在活跃地改这些技能，**存进本仓的那份就会分叉**，而分叉的复印件一旦被 `install.sh` 推出去，就是把用户的新版本盖回旧版本（mattpocock 那次实测：仓内复印件的 `domain-modeling` 还带 `CONTEXT-FORMAT.md`，上游早已把它改名 `GLOSSARY-FORMAT.md`）。Matt Pocock 自己的安装说明也是「装时从上游取，重跑一次命令即更新」。

manifest 字段：

| 字段 | 作用 |
|------|------|
| `source` | 上游地址：GitHub 仓库 URL，或 `npm:<包名>`（从发布包取） |
| `versionPolicy` | `pinned` = 取 `ref` 那个固定版本；`latest` = 取上游最新 |
| `ref` / `installedRef` | 默认要取的版本 / 上次实际取到的版本（脚本写回，追溯用） |
| `skillsPath` | 上游仓里技能目录所在位置，默认 `skills`；`.` = 仓库根自己就是一只技能 |
| `buckets` | `skillsPath` 下要取的子目录，摊平到 `~/.agents/skills/<条目名>/<技能>/`；不写 = 取它的直接子目录 |
| `exclude` / `include` | 默认减法 / 默认白名单 |
| `stripPrefix` | 落地时从技能目录名去掉的前缀（`opencli-usage` → `usage`） |

四个上游的布局各不相同，`install.sh` 都认：

| 条目 | 上游形态 | 靠什么对上 |
|------|----------|------------|
| `mattpocock` | `skills/<桶>/<名>/` 分桶 | `buckets` = engineering / productivity |
| `lark-cli` | `skills/<名>/` 平铺，不分桶 | 不写 `buckets` |
| `opencli` | `skills/opencli-<名>/`，而且**在 npm 发布包里、不在仓 main 里** | `source: npm:@jackwener/opencli` + `stripPrefix` |
| `pdf-converter` | `SKILL.md` 就在仓库根，整包即技能 | `skillsPath: "."` |

**装时询问，不直接照单执行**：交互运行会念出「上游是哪个、默认取哪版 / 哪些桶 / 哪些技能」，逐项让你改——版本可答 `l`（上游最新）或 `c`（指定编号或版本）；桶可回车用默认或另报；技能那一步先列出上游全部名字，回车=按默认，报名字=只装这些，`-名字`=在默认里去掉。`--yes` 或非终端环境下静默按 manifest 默认走。`--skills-only` 只同步 skills 不碰 CLI。

`exclude` 是**取上游时的过滤器，不是卸载表**：目标里已有的同名目录不会被删（这是「不写不删」承诺的另一面）。真想卸掉某只就手工删那个目录，别指望重跑安装脚本替你删。

**为什么 github 源的 `ref` 记 commit 而不是 tag**（实测，不是猜测）：mattpocock 的最新 tag 长期落后 `main`（当时实测差几十个提交），把 `ref` 写成 tag 就是一次倒退。要钉 tag 之前先比对它和 `main` 谁在前。

**升版流程**：装时答 `l`（或把 `ref` 改成新编号 / `versionPolicy` 设 `latest`），脚本把实际版本写回 `installedRef`；然后读上游 `CHANGELOG.md` 看这一版动了什么——作者会改名和挪桶（`to-prd`→`to-spec`、`to-issues`→`to-tickets`、`CONTEXT.md`→`GLOSSARY.md` 都发生过），挪桶时脚本会以「上游没有 xxx」停下且不改动目标。

**取法为什么是 tarball 而不是 `git clone`**：本机实测 WSL 和 Windows 侧 `git clone https://github.com/...` 连续 3 次全失败（`GnuTLS recv error (-110)` / `443 连不上` / `Connection was reset`），而 `api.github.com` 与 `codeload.github.com` 用 curl 稳定可通。所以 GitHub 源走「api 解析版本 → codeload 取 tar.gz」，`npm:` 源走 `npm view` 定版本 + `npm pack` 取包，其余源仍退回 `git clone`。

**失败不会清空你的技能**：脚本先把上游内容全部取齐并暂存校验（`skillsPath` 在、桶在、`SKILL.md` 在、选中数量 > 0），全部通过才开始写目标。取不到或一只都没选中就打印 `✗ ……已停止 —— 目标 …… 一个字没改` 并保留原有文件（包括你手写在集合根目录下的东西）。

**技能要与它依赖的 CLI 同行**（`depends` 记的就是这层关系）：顺序必须是**先升 CLI，再同步 skills**。反过来就把「引用本机还没有的命令」的技能装进去了——lark-cli 的 SKILL 里带 `cliHelp`/命令名，opencli 的技能直接写适配器命令，都是跟版本走的。而 `install.sh` 只装缺失的 CLI，**不会替你升级已有的**（已装就只做版本检测），所以升 CLI 是手动一步：`npm i -g @larksuite/cli @jackwener/opencli`。

## 自写技能（type=local）

没有可跟踪的上游、需要长期养的自家技能，复印件就放本仓 `skills/` 里，**仓内那份即真源**，要改直接改这里再跑 `install.sh`。这与上面「不存复印件」不矛盾：那条针对的是有上游可跟的东西，那种复印件才是分叉的源头。

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
      "install": "...",
      "versionPolicy": "latest",
      "installedVersion": "0.9.0"
    }
  },
  "skills": {
    "mattpocock": {
      "type": "upstream",                              // 仓内不存复印件
      "source": "https://github.com/mattpocock/skills", // 上游地址（也可写 npm:<包名>）
      "versionPolicy": "pinned",                        // pinned | latest（默认值，装时可改）
      "ref": "49dd158",                                 // 默认取哪个版本
      "installedRef": "49dd158",                        // 上次实际取到的（脚本写回）
      "skillsPath": "skills",                           // 上游里技能目录的位置，"." = 整包即技能
      "buckets": ["engineering", "productivity"],       // 取哪些子目录；不写 = 取 skillsPath 直接子目录
      "exclude": ["tdd", "code-review"],                // 默认不要的
      "include": [],                                    // 默认只要的（白名单）
      "stripPrefix": "",                                // 落地时去掉的目录名前缀
      "depends": []                                     // 依赖的 CLI
    },
    "lead-subagent-collaboration": {
      "type": "local",                                  // 本仓 skills/ 即真源
      "source": "本地自研（……）"
    }
  }
}
```

## 当前清单

### CLI / MCP

| 名称 | 类型 | 说明 |
|------|------|------|
| codebase-memory-mcp | mcp | 代码记忆库 MCP |
| opencli | cli | 浏览器自动化 CLI |
| mineru-open-api | cli | MinerU 文档转换 API CLI（pdf-converter 依赖） |
| lark-cli | cli | 飞书官方 CLI（lark-cli skills 的来源） |

装到的具体版本只在 `manifest.json` 的 `installedVersion` 里，由脚本写回、随 git history 追溯，不抄进本文档。

### Skills

| 条目 | type | 上游 | 备注 |
|------|------|------|------|
| `mattpocock` | upstream | [mattpocock/skills](https://github.com/mattpocock/skills) | 分桶取 engineering / productivity，`exclude` 只是默认减法 |
| `lark-cli` | upstream | [larksuite/cli](https://github.com/larksuite/cli) 的 `skills/` | 平铺不分桶；`lark-meeting` **必装**——上游把视频会议那组合并进它，`lark-vc` / `lark-vc-agent` / `lark-minutes` / `lark-note` 都只是指向它的委派桩 |
| `opencli` | upstream | `npm:@jackwener/opencli` 发布包内 `skills/` | **发布包与仓 main 已不一致**（见 manifest notes）；落地去 `opencli-` 前缀 |
| `pdf-converter` | upstream | [tanis90/pdf-converter-mineru](https://github.com/tanis90/pdf-converter-mineru) | 单技能仓，整包即技能 |
| `lead-subagent-collaboration` | local | 无上游 | 本仓 `skills/` 即真源 |
| `skill-creator` | local | 无上游（外部候选评估结论见 manifest notes） | 本仓 `skills/` 即真源；落盘走「目录由用户点名、不凭空创建、不静默覆盖」 |

装了哪几只、取到哪个版本不写在这里——那由装时的回答决定，脚本记在 `installedRef`。

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
