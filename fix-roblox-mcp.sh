#!/usr/bin/env bash
# ============================================================
#  Roblox-MCP · 一键诊断 + 修复（Codespaces 用）
#
#  融合自 NBYYDSKMKOP/Roblox-MCP 的 fix-roblox-mcp.sh，
#  并修掉以下问题：
#    · 不依赖 python3（改用 node）
#    · 验证路径用 /api/status（原版用了不存在的 /status）
#    · 补丁标记与主流程统一为 BridgeHttpBase
#    · npm install 加 --ignore-scripts / --no-package-lock
#
#  用法（Codespace 终端，任意目录）：
#    bash fix-roblox-mcp.sh
# ============================================================
set -u

PORT=16384
say()  { printf '\033[1;36m[fix]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[fix!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[fix!]\033[0m %s\n' "$*"; exit 1; }

# ---------- 0. 需要 node（提炼自 deploy-codespaces.sh 的 nvm 加载逻辑） ----------
if ! command -v node >/dev/null 2>&1; then
  say "未检测到 node，尝试通过 nvm 加载..."
  for nvmf in "$NVM_DIR/nvm.sh" "$HOME/.nvm/nvm.sh" \
              "/usr/local/share/nvm/nvm.sh" "/usr/local/nvm/nvm.sh"; do
    if [ -s "$nvmf" ]; then
      # shellcheck disable=SC1090
      . "$nvmf"
      say "已加载 nvm: $nvmf"
      break
    fi
  done
fi

if ! command -v node >/dev/null 2>&1; then
  die "未找到 node，且无法通过 nvm 加载。请先启用 Node >= 20。"
fi

NODE_MAJOR="$(node -v | sed 's/v\([0-9]*\).*/\1/')"
if [ "${NODE_MAJOR:-0}" -lt 20 ]; then
  warn "当前 Node $(node -v) 低于 v20，可能有兼容问题"
  for nvmf in "$NVM_DIR/nvm.sh" "$HOME/.nvm/nvm.sh" \
              "/usr/local/share/nvm/nvm.sh" "/usr/local/nvm/nvm.sh"; do
    [ -s "$nvmf" ] || continue
    # shellcheck disable=SC1090
    . "$nvmf"
    if command -v nvm >/dev/null 2>&1; then
      nvm install 22 >/dev/null 2>&1 && nvm use 22 >/dev/null 2>&1 \
        && say "已切换到 Node $(node -v)"
    fi
    break
  done
fi

say "node: $(node -v)"

# ---------- 1. 定位项目目录 ----------
SRV_PID=""
for f in /proc/[0-9]*/cmdline; do
  [ -r "$f" ] || continue
  p="${f#/proc/}"; p="${p%/cmdline}"
  [ "$p" = "$$" ] && continue
  case "$(tr '\0' ' ' < "$f" 2>/dev/null)" in
    *"dist/index.js"*) SRV_PID="$p"; break ;;
  esac
done

APP_DIR=""
if [ -n "$SRV_PID" ]; then
  APP_DIR="$(readlink -f "/proc/$SRV_PID/cwd" 2>/dev/null || true)"
  say "发现运行中的 server (pid=$SRV_PID)  目录: ${APP_DIR:-无法读取}"
fi

if [ -z "$APP_DIR" ] || [ ! -d "$APP_DIR/src" ]; then
  GITROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  for d in "$HOME/roblox-mcp" "$HOME/Roblox-MCP" "$PWD" "$GITROOT"; do
    [ -n "$d" ] || continue
    if [ -d "$d/src" ] && [ -f "$d/package.json" ]; then APP_DIR="$d"; break; fi
  done
fi

if [ -z "$APP_DIR" ] || [ ! -d "$APP_DIR/src" ]; then
  die "无法定位项目目录（需含 src/ 与 package.json）。请在项目根目录运行。"
fi
say "项目目录: $APP_DIR"
cd "$APP_DIR" || die "无法进入 $APP_DIR"

# ---------- 2. 停掉旧 server ----------
if [ -n "$SRV_PID" ]; then
  say "停止旧 server (pid=$SRV_PID)"
  kill -9 "$SRV_PID" 2>/dev/null || true
fi
for f in /proc/[0-9]*/cmdline; do
  [ -r "$f" ] || continue
  p="${f#/proc/}"; p="${p%/cmdline}"
  [ "$p" = "$$" ] && continue
  case "$(tr '\0' ' ' < "$f" 2>/dev/null)" in
    *"dist/index.js"*) kill -9 "$p" 2>/dev/null || true ;;
  esac
done
sleep 1

# ---------- 3. 检查 dist 完整性 ----------
say "检查 dist 完整性"
NEED_BUILD=0
if [ ! -f "dist/index.js" ]; then
  warn "dist/index.js 缺失"; NEED_BUILD=1
elif [ ! -f "dist/http/routes/script.luau.js" ]; then
  warn "dist/http/routes/script.luau.js 缺失 —— 这是 /script.luau 404 的直接原因"; NEED_BUILD=1
fi

if [ "$NEED_BUILD" -eq 1 ]; then
  export COREPACK_ENABLE_STRICT=0
  if [ ! -d node_modules ]; then
    say "安装依赖（npm，跳过 prepare 钩子）"
    npm install --no-package-lock --ignore-scripts --no-audit --no-fund 2>&1 | tail -5
  fi
  say "构建（npm run build）"
  npm run build 2>&1 | tail -6 || die "npm run build 失败"
  say "构建完成"
else
  say "dist 完整，跳过构建"
fi

# ---------- 4. connector.luau 补丁（node 实现） ----------
say "检查 connector.luau 协议补丁"
if grep -q 'BridgeHttpBase' connector.luau 2>/dev/null; then
  say "补丁已存在，跳过"
else
  node .devcontainer/patch-connector.mjs "$APP_DIR/connector.luau" 2>/dev/null \
    || node -e '
const fs = require("fs");
const FILE = "connector.luau";
let s = fs.readFileSync(FILE, "utf8");
const anchor = `local BridgeURL = getgenv().BridgeURL or ... or "localhost:16384"`;
if (!s.includes(anchor)) { console.error("未找到 BridgeURL 锚点"); process.exit(1); }
const helper = `${anchor}

--// Protocol Auto-Detect (https/wss) \\--
local BridgeHttpBase, BridgeWsBase
do
    local raw = tostring(BridgeURL or "")
    raw = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
    if raw:match("^https://") then
        BridgeHttpBase = raw
        BridgeWsBase = raw:gsub("^https://", "wss://")
    elseif raw:match("^wss://") then
        BridgeWsBase = raw
        BridgeHttpBase = raw:gsub("^wss://", "https://")
    elseif raw:match("^http://") then
        BridgeHttpBase = raw
        BridgeWsBase = raw:gsub("^http://", "ws://")
    elseif raw:match("^ws://") then
        BridgeWsBase = raw
        BridgeHttpBase = raw:gsub("^ws://", "http://")
    else
        BridgeHttpBase = "http://" .. raw
        BridgeWsBase = "ws://" .. raw
    end
end`;
s = s.replace(anchor, helper);
const reps = [
  [`Url = "http://" .. BridgeURL,`, "Url = BridgeHttpBase,"],
  [`WebSocket.connect("ws://" .. BridgeURL)`, "WebSocket.connect(BridgeWsBase)"],
  [`Url = "http://" .. BridgeURL .. "/register",`, `Url = BridgeHttpBase .. "/register",`],
  [`local pollUrl = "http://" .. BridgeURL .. "/poll"`, `local pollUrl = BridgeHttpBase .. "/poll"`],
  [`Url = "http://" .. BridgeURL .. "/respond",`, `Url = BridgeHttpBase .. "/respond",`],
  [`Url = "http://" .. BridgeURL .. "/script-sources",`, `Url = BridgeHttpBase .. "/script-sources",`],
];
let n = 0;
for (const [a, b] of reps) {
  const c = s.split(a).length - 1;
  if (c === 0) { console.error("未匹配: " + a); process.exit(1); }
  s = s.split(a).join(b); n += c;
}
fs.writeFileSync(FILE, s);
console.log("  替换 " + n + " 处硬编码协议");
' || die "补丁失败"
  say "补丁已应用"
fi

# ---------- 5. 重启 server ----------
say "启动 server（端口 $PORT）"
mkdir -p logs
: > logs/server.log
setsid nohup node dist/index.js >> logs/server.log 2>&1 &
echo "$!" > logs/server.pid
sleep 2

READY=0
for _ in $(seq 1 40); do
  curl -sS -m 2 -o /dev/null "http://127.0.0.1:$PORT/api/status" 2>/dev/null && { READY=1; break; }
  sleep 0.5
done

if [ "$READY" != "1" ]; then
  warn "server 未就绪，日志："
  tail -20 logs/server.log | sed 's/^/    /'
  exit 1
fi

# ---------- 6. 自验证 ----------
say "验证 /api/status"
curl -sS -m 5 "http://127.0.0.1:$PORT/api/status" | sed 's/^/    /'
echo

say "验证 /script.luau"
SC=$(curl -sS -m 8 "http://127.0.0.1:$PORT/script.luau" 2>/dev/null | grep -c 'BridgeHttpBase')
SC=${SC:-0}
if [ "$SC" -ge 1 ]; then
  say "OK  /script.luau 正常（补丁标记 x$SC）"
else
  warn "/script.luau 未含补丁标记（计数=$SC）"
  tail -15 logs/server.log | sed 's/^/    /'
fi

# ---------- 7. 端口 + 注入脚本 ----------
FWD=""
if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
  gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME" >/dev/null 2>&1 \
    && say "端口 $PORT 已设为 public"
  FWD="https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
fi

if [ -z "$FWD" ]; then
  warn "未获取到转发地址，请到 PORTS 面板复制端口 $PORT 的地址并设为 Public"
fi

echo
echo "============================================================"
echo " Roblox 执行器注入："
echo "============================================================"
if [ -n "$FWD" ]; then
  echo "getgenv().BridgeURL = \"$FWD\""
  echo "loadstring(game:HttpGet(\"$FWD/script.luau\"))()"
else
  echo "getgenv().BridgeURL = \"<转发地址>\""
  echo "loadstring(game:HttpGet(\"<转发地址>/script.luau\"))()"
fi
echo "============================================================"
echo " BridgeURL 必须带 https:// （自动转 wss 给 WebSocket）"
echo "============================================================"