#!/usr/bin/env bash
# oh-my-agentpack 安装/同步脚本
# 职责：同步 skills 到 ~/.agents/skills/ + 安装缺失的 CLI + 记录当前版本到 manifest
# skills 两种来源：type=local/vendor 用仓内复印件；type=upstream 装时从上游取（仓内不留复印件）
# 版本策略：CLI 一律 latest（不固定），installedVersion 仅作追溯记录（随 git history 演进）
#           upstream skills 取哪个版本、装哪几只由装时决定；manifest 的 ref / installedRef
#           只是「上次用的值」当默认，不是承诺，也不代表实装数量
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_DIR/manifest.json"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="${AGENTS_SKILLS_DIR:-${HOME}/.agents/skills}"

ASSUME_YES=0
SKILLS_ONLY=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)        ASSUME_YES=1 ;;
        --skills-only)   SKILLS_ONLY=1 ;;
        -h|--help)
            echo "用法: $0 [-y|--yes] [--skills-only] "
            echo "  -y, --yes        不提问，全按 manifest 里记的策略走"
            echo "  --skills-only    只同步 skills，不碰 CLI/MCP"
            echo "  AGENTS_SKILLS_DIR=...  覆盖目标目录（验证用，默认 ~/.agents/skills）"
            exit 0 ;;
        *) echo "错误: 未知参数 '$arg'（试试 --help）"; exit 1 ;;
    esac
done

echo "=== oh-my-agentpack 安装 ==="
echo "定位: agent 无关的 CLI/MCP + 全局 skills 清单"
echo "版本策略: CLI 用 latest；upstream skills 装时问（manifest 记的值只当默认）"
echo ""

# ------------------------------------------------------------
# 1. 同步 skills
#    type=vendor/local：仓库 skills/<名>/ = 真源，整目录覆盖目标同名目录
#    type=upstream：先从上游取齐并校验，再只覆盖取到的技能目录
#      —— 目标集合根目录下的文件（如手写的 README.md）与未被本次清单管理的
#         目录一律不写不删；取失败时不改动目标（先删后拷在断网时会清空用户技能）
#    装时交互会念出「上游有哪些、默认装哪些」并让人改；--yes 静默按 manifest 走。
#    manifest 中 enabled=false 的技能跳过（不同机器可选装）
# ------------------------------------------------------------

sync_vendor() {
    local skill="$1" stype="${2:-vendor}"
    if [ ! -d "$SKILLS_SRC/$skill" ]; then
        echo "  ✗ $skill: 仓库内缺失（skills/$skill 不存在），跳过"
        return
    fi
    rm -rf "${SKILLS_DST:?}/$skill"
    cp -r "$SKILLS_SRC/$skill" "$SKILLS_DST/$skill"
    echo "  ✓ $skill（$stype，来自仓内复印件）"
    CHANGED=1
}

# 取上游内容到 $3 目录，把实际版本号（github=commit 前 7 位 / npm=包版本）打到 stdout；
# 失败返回 1 且不碰目标。源写法决定取法：
#   npm:<包名>   → npm pack 取发布包（发布产物可能与仓库 main 不一致，见 manifest notes）
#   *github.com* → api.github.com 解析编号 + codeload 取 tar.gz。本机实测 WSL/Windows 的
#                  git clone 到 github.com 三次全挂（TLS 中断 / 443 连不上），这两个域名却通。
#   其他         → git clone
fetch_upstream() {
    local source="$1" want="$2" dest="$3" slug resolved
    slug=$(printf '%s' "$source" | sed -e 's#\.git$##' -e 's#^.*github\.com[/:]##')
    case "$source" in
        npm:*)
            local pkg="${source#npm:}" spec ver tgz
            spec="$pkg"
            [ -n "$want" ] && [ "$want" != "HEAD" ] && spec="$pkg@$want"
            if ! ver=$(npm view "$spec" version 2>/dev/null | tail -1) || [ -z "$ver" ]; then
                echo "      npm 查不到 $spec 的版本（包名或版本写错了？注册表不通？）" >&2
                return 1
            fi
            mkdir -p "$dest"
            if ! tgz=$(npm pack "$pkg@$ver" --pack-destination "$dest" 2>/dev/null | tail -1) ||
               [ ! -f "$dest/$tgz" ]; then
                echo "      npm pack 失败：$pkg@$ver" >&2
                return 1
            fi
            tar xzf "$dest/$tgz" -C "$dest" --strip-components=1 || { echo "      解包失败" >&2; return 1; }
            rm -f "$dest/$tgz"
            printf '%s' "$ver"
            return 0
            ;;
        *github.com*)
            local curl=(curl -fsSL --connect-timeout 15 --max-time 300 --retry 2)
            if ! resolved=$("${curl[@]}" "https://api.github.com/repos/$slug/commits/$want" \
                    | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha"][:7])' 2>/dev/null); then
                echo "      api.github.com 取不到编号 $want（$slug）" >&2
                return 1
            fi
            mkdir -p "$dest"
            if ! "${curl[@]}" -o "$dest.tgz" "https://codeload.github.com/$slug/tar.gz/$resolved"; then
                echo "      codeload 下载失败（$slug @ $resolved）" >&2
                return 1
            fi
            tar xzf "$dest.tgz" -C "$dest" --strip-components=1 || { echo "      解包失败" >&2; return 1; }
            rm -f "$dest.tgz"
            printf '%s' "$resolved"
            return 0
            ;;
    esac
    if ! git clone --quiet "$source" "$dest" 2>"$dest.clone.err"; then
        echo "      上游克隆失败：$source" >&2
        sed 's/^/        /' "$dest.clone.err" | head -3 >&2
        return 1
    fi
    rm -f "$dest.clone.err"
    if [ -n "$want" ] && [ "$want" != "HEAD" ] && \
       ! git -C "$dest" checkout --quiet --detach "$want" 2>"$dest.co.err"; then
        echo "      上游没有编号 $want" >&2
        sed 's/^/        /' "$dest.co.err" | head -2 >&2
        return 1
    fi
    rm -f "$dest.co.err"
    git -C "$dest" rev-parse --short=7 HEAD
}

# 上游里哪些算技能：$1（上游仓里的 skillsPath 目录）自己就带 SKILL.md → 整包是 1 只技能（用
# manifest 条目名当目录名）；否则取 <$1>/<桶>/*/ 里带 SKILL.md 的目录，名字去掉 stripPrefix 后
# 暂存（opencli 的上游目录叫 opencli-usage，落地要叫 usage）。技能名逐个打到 stdout；
# 布局不合预期返回 1，此时目标目录还没被碰过。
stage_skills() {
    local base="$1" staged="$2" buckets="$3" stripprefix="$4" skill="$5"
    local b bd dir name
    mkdir -p "$staged"
    if [ -f "$base/SKILL.md" ]; then
        cp -r "$base" "$staged/$skill"
        rm -rf "${staged:?}/$skill/.git"   # 非 github 源是 clone 来的，别把版本库拷进技能目录
        printf '%s\n' "$skill"
        return 0
    fi
    for b in $buckets; do
        bd="$base"
        [ "$b" != "." ] && bd="$base/$b"
        if [ ! -d "$bd" ]; then
            echo "      上游没有 $b（作者挪过桶位？）" >&2
            return 1
        fi
        for dir in "$bd"/*/; do
            [ -f "${dir}SKILL.md" ] || continue
            name=$(basename "$dir")
            [ -n "$stripprefix" ] && name="${name#"$stripprefix"}"
            if [ -e "$staged/$name" ]; then
                echo "      两处出现同名技能 $name，摊平会互相覆盖" >&2
                return 1
            fi
            cp -r "$dir" "$staged/$name"
            printf '%s\n' "$name"
        done
    done
}

sync_upstream() {
    local skill="$1"
    local cfg SOURCE POLICY REF SKILLSPATH BUCKETS EXCLUDE INCLUDE STRIPPREFIX ans
    cfg=$(python3 - "$MANIFEST" "$skill" <<'PY'
import json, sys
e = json.load(open(sys.argv[1]))["skills"][sys.argv[2]]
for key, default in (("source", ""), ("versionPolicy", "pinned"), ("ref", ""), ("skillsPath", "skills")):
    print(e.get(key, default))
for key in ("buckets", "exclude", "include"):
    print(" ".join(e.get(key, [])))
print(e.get("stripPrefix", ""))
PY
)
    { read -r SOURCE; read -r POLICY; read -r REF; read -r SKILLSPATH;
      read -r BUCKETS; read -r EXCLUDE; read -r INCLUDE; read -r STRIPPREFIX; } <<<"$cfg"
    [ -z "$SKILLSPATH" ] && SKILLSPATH="skills"
    [ -z "$BUCKETS" ] && BUCKETS="."

    if [ -z "$SOURCE" ]; then
        echo "  ✗ $skill: manifest 缺 source，跳过（未改动目标）"
        return
    fi
    if [ "$POLICY" != "latest" ] && [ -z "$REF" ]; then
        echo "  ✗ $skill: manifest 既没记 ref 也不是 latest，取不出版本（未改动目标）"
        return
    fi

    # 交互时让人（或驱动它的 AI）现选：取哪版、取哪些桶、装哪几只；回车 = 用 manifest 的默认值
    # 注意读 /dev/tty：本函数在被 while read 循环调用，stdin 已被清单占用
    if [ "$INTERACTIVE" = "1" ]; then
        echo "  [$skill] 上游 $SOURCE"
        echo "      manifest 默认: 策略=$POLICY${REF:+ 锁定=$REF}${EXCLUDE:+ 排除=$EXCLUDE}${INCLUDE:+ 只装=$INCLUDE}"
        printf '      取哪个版本？ [回车=按默认] / l=上游最新 / c=指定编号或版本 > '
        read -r ans </dev/tty || ans=""
        case "$ans" in
            l|L|latest) POLICY=latest; REF="" ;;
            c|C) printf '      输入 commit 或版本 > '
                 read -r REF </dev/tty || REF=""
                 [ -z "$REF" ] && { POLICY=latest; REF=""; } ;;
        esac
        if [ "$SKILLSPATH" != "." ]; then
            printf '      取哪些桶？[回车=%s] > ' "$BUCKETS"
            read -r ans </dev/tty || ans=""
            [ -n "$ans" ] && BUCKETS=$ans
        fi
    fi

    local want="$REF"
    [ "$POLICY" = "latest" ] && want="HEAD"

    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN

    local resolved
    if ! resolved=$(fetch_upstream "$SOURCE" "$want" "$tmp/repo"); then
        echo "  ✗ $skill: 取上游失败，已停止 —— 目标 $SKILLS_DST/$skill 一个字没改"
        echo "      本机已知问题: WSL 直连 github.com 不稳（manifest 记过）。重试或换时段再跑。"
        return 1
    fi

    # 先把上游内容全部暂存到临时目录并校验，一只都不少才开始写目标
    local staged="$tmp/set" all=() name dir
    local sbase="$tmp/repo/$SKILLSPATH" SINGLE=0
    [ "$SKILLSPATH" = "." ] && sbase="$tmp/repo"
    [ -f "$sbase/SKILL.md" ] && SINGLE=1
    local names_raw
    if ! names_raw=$(stage_skills "$sbase" "$staged" "$BUCKETS" "$STRIPPREFIX" "$skill"); then
        echo "  ✗ $skill: 上游布局不合预期，已停止 —— 目标 $SKILLS_DST/$skill 一个字没改"
        return 1
    fi
    while IFS= read -r name; do [ -n "$name" ] && all+=("$name"); done <<<"$names_raw"

    # manifest 里的默认取舍：exclude 做减法，include 做白名单
    for name in "${all[@]}"; do
        case " $EXCLUDE " in *" $name "*) rm -rf "${staged:?}/$name" ;; esac
        if [ -n "$INCLUDE" ]; then
            case " $INCLUDE " in *" $name "*) ;; *) rm -rf "${staged:?}/$name" ;; esac
        fi
    done

    if [ "$INTERACTIVE" = "1" ] && [ "$SINGLE" != "1" ]; then
        local default_count=0 bd
        for bd in "$staged"/*/; do [ -d "$bd" ] && default_count=$((default_count + 1)); done
        echo "      上游取到 ${#all[@]} 只:${all[*]}"
        printf '      装哪些？[回车=默认 %s 只] / 名字…=只装这些 / -名字…=再从默认里去掉 > ' "$default_count"
        read -r ans </dev/tty || ans=""
        case "$ans" in
            "") : ;;
            -*) for name in ${ans#-}; do rm -rf "${staged:?}/$name"; done ;;
            *)  for name in "${all[@]}"; do
                    case " $ans " in *" $name "*) ;; *) rm -rf "${staged:?}/$name" ;; esac
                done ;;
        esac
    fi

    local count=0
    for dir in "$staged"/*/; do [ -d "$dir" ] && count=$((count + 1)); done
    if [ "$count" = "0" ]; then
        echo "  ✗ $skill: 一只都没选中（桶名或排除表写错了？），已停止 —— 目标没改"
        return 1
    fi

    mkdir -p "$SKILLS_DST"
    if [ "$SINGLE" = "1" ]; then
        # 整包即技能：集合目录就是技能目录，整体换成上游这份
        rm -rf "${SKILLS_DST:?}/$skill"
        cp -r "$staged/$skill" "$SKILLS_DST/$skill"
    else
        mkdir -p "$SKILLS_DST/$skill"
        for dir in "$staged"/*/; do
            [ -d "$dir" ] || continue
            name=$(basename "$dir")
            rm -rf "${SKILLS_DST:?}/$skill/$name"
            cp -r "$dir" "$SKILLS_DST/$skill/$name"
        done
    fi

    # 目标里没被本次清单管起来的东西：点名但不碰（整包即技能时目录里全是我写的，没什么可报）
    local kept="" entry
    if [ "$SINGLE" != "1" ]; then
        for entry in "$SKILLS_DST/$skill"/*; do
            [ -e "$entry" ] || continue
            name=$(basename "$entry")
            [ -d "$staged/$name" ] && continue
            kept="$kept $name"
        done
    fi

    python3 - "$MANIFEST" "$skill" "$resolved" <<'PY'
import json, sys
path, skill, ref = sys.argv[1:4]
m = json.load(open(path))
e = m["skills"][skill]
if e.get("installedRef") != ref:
    e["installedRef"] = ref
    json.dump(m, open(path, "w"), indent=2, ensure_ascii=False)
    open(path, "a").write("\n")
    print(f"    manifest.installedRef 已更新: {ref}")
PY
    echo "  ✓ $skill（上游 $resolved，本次写入 $count 只${kept:+；未纳管的保留:$kept}）"
    CHANGED=1
}

echo "=== [skills] 同步到 $SKILLS_DST ==="
# 是否提问：必须在进入 read 循环之前判断（进了循环 stdin 就不是终端了）
INTERACTIVE=0
if [ "$ASSUME_YES" != "1" ] && [ -t 0 ]; then
    INTERACTIVE=1
fi
mkdir -p "$SKILLS_DST"
CHANGED=0
SKILLS_PLAN=$(python3 -c "
import json
m=json.load(open('$MANIFEST'))
for name,info in m['skills'].items():
    if info.get('enabled', True):
        print(f\"{name}|{info.get('type','vendor')}\")
")
SKILLS_DISABLED=$(python3 -c "
import json
m=json.load(open('$MANIFEST'))
print(' '.join(k for k,v in m['skills'].items() if not v.get('enabled', True)))
")
FAILED=""
while IFS='|' read -r skill stype; do
    [ -z "$skill" ] && continue
    case "$stype" in
        vendor|local) sync_vendor "$skill" "$stype" || FAILED="$FAILED $skill" ;;
        upstream)     sync_upstream "$skill"        || FAILED="$FAILED $skill" ;;
        *)            echo "  ✗ $skill: 未知 type=$stype，跳过" ;;
    esac
done <<<"$SKILLS_PLAN"
[ -n "$SKILLS_DISABLED" ] && echo "  ⏭ 跳过（enabled=false）:$SKILLS_DISABLED"
[ -n "$FAILED" ] && echo "  ⚠ 这些没同步成功，目标目录保持原样:$FAILED"
[ "$CHANGED" = "1" ] && echo "  注意: 若 kb-access 等未列出项仍在 ~/.agents/skills/ 中，不受影响"
echo ""

if [ "$SKILLS_ONLY" = "1" ]; then
    echo "=== --skills-only：跳过 CLI/MCP 安装 ==="
    echo "=== 完成 ==="
    exit 0
fi

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
    if not info.get('enabled', True):
        continue
    print(f\"{name}|{info['bin']}|{info['versionCmd']}|{info['install']}\")
")
CLI_DISABLED=$(python3 -c "
import json
m=json.load(open('$MANIFEST'))
print(' '.join(k for k,v in m['cli'].items() if not v.get('enabled', True)))
")
while IFS='|' read -r name bin vcmd icmd; do
    [ -z "$name" ] && continue
    install_or_record "$name" "$bin" "$vcmd" "$icmd"
done <<< "$CLI_LIST"
[ -n "$CLI_DISABLED" ] && echo "  ⏭ 跳过（enabled=false）: $CLI_DISABLED"

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
