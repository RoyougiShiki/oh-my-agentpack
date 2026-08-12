#!/usr/bin/env bash
# oh-my-agentpack 安装/同步脚本
# 职责：同步 skills 到 ~/.agents/skills/ + 安装缺失的 CLI + 记录当前版本到 manifest
# 版本策略：CLI 一律 latest（不固定），installedVersion 仅作追溯记录（随 git history 演进）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_DIR/manifest.json"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="${HOME}/.agents/skills"

echo "=== oh-my-agentpack 安装 ==="
echo "定位: agent 无关的 CLI/MCP + 全局 skills 清单"
echo "版本策略: CLI 用 latest；installedVersion 记录当前使用版本供追溯"
echo ""

# ------------------------------------------------------------
# 1. 同步 skills（仓库 = 真源，覆盖目标同名目录；不动未列出的项）
# ------------------------------------------------------------
echo "=== [skills] 同步到 $SKILLS_DST ==="
mkdir -p "$SKILLS_DST"
CHANGED=0
for skill in $(python3 -c "
import json,sys
m=json.load(open('$MANIFEST'))
print(' '.join(m['skills'].keys()))
"); do
    if [ -d "$SKILLS_SRC/$skill" ]; then
        rm -rf "$SKILLS_DST/$skill"
        cp -r "$SKILLS_SRC/$skill" "$SKILLS_DST/$skill"
        echo "  ✓ $skill"
        CHANGED=1
    else
        echo "  ✗ $skill: 仓库内缺失（skills/$skill 不存在），跳过"
    fi
done
[ "$CHANGED" = "1" ] && echo "  注意: 若 kb-access 等未列出项仍在 ~/.agents/skills/ 中，不受影响"

# ------------------------------------------------------------
# 2. CLI/MCP 安装（缺失才装）+ 版本检测
# ------------------------------------------------------------
echo ""
echo "=== [cli] 安装缺失项 + 记录版本 ==="

install_or_record() {
    local name="$1" bin="$2" version_cmd="$3" install_cmd="$4"
    if command -v "$name" >/dev/null 2>&1; then
        echo "  ✓ $name 已安装"
    else
        echo "  ⚠ $name 未安装，执行: $install_cmd"
        eval "$install_cmd" || echo "  ✗ $name 安装失败（可稍后手动安装）"
    fi
    # 版本检测并写回 manifest（追溯用）
    # 取最后非日志行的最后一个字段，兼容三种输出：
    #   "codebase-memory-mcp 0.6.1" / "1.8.6" / "mineru-open-api version v0.5.9"
    local ver
    ver=$(eval "$version_cmd" 2>/dev/null | grep -v 'level=info' | tail -1 | awk '{print $NF}' | tr -d '[:space:]') || ver="unknown"
    echo "  → $name 当前版本: ${ver:-unknown}"
    python3 - "$MANIFEST" "$name" "$ver" << 'PYEOF'
import json, sys
path, name, ver = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(path))
if name in m["cli"] and m["cli"][name].get("installedVersion") != ver:
    m["cli"][name]["installedVersion"] = ver
    json.dump(m, open(path, "w"), indent=2, ensure_ascii=False)
    open(path, "a").write("\n")
    print(f"    manifest.installedVersion 已更新: {ver}")
PYEOF
}

CLI_LIST=$(python3 -c "
import json
m=json.load(open('$MANIFEST'))
for name,info in m['cli'].items():
    print(f\"{name}|{info['bin']}|{info['versionCmd']}|{info['install']}\")
")
while IFS='|' read -r name bin vcmd icmd; do
    [ -z "$name" ] && continue
    install_or_record "$name" "$bin" "$vcmd" "$icmd"
done <<< "$CLI_LIST"

# ------------------------------------------------------------
# 3. 手工项提醒
# ------------------------------------------------------------
echo ""
echo "=== 手工项（需人工确认） ==="
echo "  1. opencli 浏览器扩展: Chrome Web Store 搜索 opencli（ID: ildkmabpimmkaediidaifkhjpohdnifk）"
echo "  2. codebase-memory-mcp 的 MCP 服务器配置（pi 侧在 ~/.config/mcp/mcp.json，由 pi-PackgeManager 模板生成）"
echo "  3. mineru-open-api auth（如需 extract 模式解锁）"
echo ""
echo "=== 完成 ==="
echo "  skills 已同步；版本记录已写入 manifest.json"
echo "  建议: git add manifest.json && git commit -m \"chore: record installed versions\""
