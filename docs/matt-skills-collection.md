# Matt Pocock 技能集合：位置与项目侧约定

这份说明取代 `~/.agents/skills/mattpocock/README.md`（2026-10-11 移入本仓）。原文逐字存在
[`archive/mattpocock-collection-README-2026-10-11.md`](archive/mattpocock-collection-README-2026-10-11.md)，
md5 `f3cbe7c678a552c675d28c799ce58cb1`。

移走而不是就地更新的原因：那份的「同步 SOP」教人 `git clone` 上游再 `cp -r` 覆盖集合目录，
而那正是本仓刚拆掉的「两份源」问题。把那张图纸留在技能目录里，等于随时可以把它重新造回来。
（它当时的成员表也已经是第三回对不上实际：上游 v1.1.0 快照写 9、集合目录写 8、磁盘上实有 14。）

## 物理位置

- 集合目录：`~/.agents/skills/mattpocock/`
- `~/.agents/skills` 是指向 Windows 侧目录的符号链接，物理位置 `/mnt/c/Users/h/.agents/skills/`
- pi 递归发现该目录下每个含 `SKILL.md` 的子目录；集合这层目录只是文件组织，不影响使用

## 装什么、装到哪个版本

不在这里记，记在 [`../manifest.json`](../manifest.json) 的 `skills.mattpocock`：
`ref`（要取的 commit）/ `installedRef`（上次实际取到的）/ `buckets` / `exclude`。
机制与升版流程见 [`../README.md`](../README.md) 的「上游型技能（type=upstream）」一节。

## 项目侧约定

- 各项目用自己的 `AGENTS.md` 声明技能约定，落在 `## Agent skills` 一节。
  ⚠️ 2026-10-08 更正：早期写的 `### Global skill set` 在各仓 `AGENTS.md` 里并不存在。
- 工作流决策见各仓 `docs/adr/0008-*`。
- digital-textbooks 仓的 map/ticket 约定真源 = 该仓 `docs/agents/wayfinder.md`；
  `docs/agents/issue-tracker.md` 只留一节定位指针。
