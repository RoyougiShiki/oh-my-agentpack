# Matt Pocock Skill Collection (Global)

Matt Pocock 工作流技能的全局集合，安装于 `~/.agents/skills/mattpocock/`。
pi 递归发现该目录下每个含 `SKILL.md` 的子目录，集合只是文件组织，不影响使用。

**物理位置**：`/mnt/c/Users/h/.agents/skills/mattpocock/`
（`~/.agents/skills` 是指向 Windows 侧目录的符号链接）
**来源**：`https://github.com/mattpocock/skills`，快照安装于 2026-08-04（上游 v1.1.0，commit 未固定）
**落地说明**：项目 `AGENTS.md` → `### Global skill set`；工作流决策见 `docs/adr/0008-*`。

## 成员（9 个）

| skill | 触发 | 用途 |
|---|---|---|
| `grill-with-docs` | 手动 | 对齐想法 + 维护 CONTEXT.md/ADR |
| `wayfinder` | 手动 | 大工程：决策票地图（map.md + issues/NN-*.md） |
| `to-spec` | 手动 | 对话 → spec 落 issue tracker |
| `setup-matt-pocock-skills` | 手动（一次性） | 仓库配置（当前项目已完成） |
| `grilling` | 自动 | 面试原语（grill-with-docs/wayfinder 内部调用） |
| `domain-modeling` | 自动 | 领域模型/ADR 维护 |
| `research` | 自动 | 后台 subagent 查主源 |
| `prototype` | 自动 | 一次性原型验证 |

（`grill-me`、`handoff` 于 2026-08-04 移除；需要时从仓库 `skills/productivity/` 恢复。）

## 同步 SOP（作者仓库活跃，定期对照）

```bash
# 1. 拉最新
git clone --depth 1 https://github.com/mattpocock/skills /tmp/skills-sync
# 2. 对照 diff（看哪些 skill 有变化，尤其新老目录调整）
diff -r /tmp/skills-sync/skills/productivity/grilling ~/.agents/skills/mattpocock/grilling
diff -r /tmp/skills-sync/skills/engineering/wayfinder ~/.agents/skills/mattpocock/wayfinder
# 3. 只覆盖有意义的（保持手动触发 skill 阈值）
cp -r /tmp/skills-sync/skills/engineering/{grill-with-docs,wayfinder,to-spec,setup-matt-pocock-skills,domain-modeling,research,prototype}/. ~/.agents/skills/mattpocock/
cp -r /tmp/skills-sync/skills/productivity/grilling/. ~/.agents/skills/mattpocock/grilling/

# 注意：作者偶尔会改名/移动 skill（见 CHANGELOG：to-prd→to-spec、to-issues→to-tickets…），
# 步骤 2 的 diff 前先看上游 README 的 skill 列表是否出现重命名。
```