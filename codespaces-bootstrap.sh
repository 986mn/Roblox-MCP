#!/usr/bin/env bash
# ============================================================
#  Roblox-MCP · GitHub Codespaces 一键部署脚本
#  在 Codespaces 终端、仓库根目录下执行：
#      bash codespaces-bootstrap.sh
#
#  它做 5 件事：
#   1. 给 connector.luau 打「协议自适应」补丁（Codespaces 必需）
#      —— 原版硬编码 http:// 与 ws://，在 https 转发下必然连不上
#   2. 安装依赖
#   3. 编译 TypeScript
#   4. 后台常驻启动桥接服务（端口 16384）
#   5. 尝试把 16384 设为 public 并打印连接信息
# ============================================================

set -u

PORT=16384
ROOT="${CODESPACE_VSCODE_FOLDER:-$(pwd)}"
cd "$ROOT" 2>/dev/null || { echo "无法进入目录: $ROOT"; exit 1; }

# 避免 corepack 因 packageManager 字段强制切换包管理器
export COREPACK_ENABLE_STRICT=0

echo "============================================"
echo " Roblox-MCP · Codespaces 部署"
echo " 仓库: $ROOT"
echo "============================================"

# ---------- 0. 环境检查 ----------
echo
echo "[0/5] 环境检查"
command -v node >/dev/null 2>&1 || { echo "  ✗ 缺少 node"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "  ✗ 缺少 npm"; exit 1; }
echo "  node $(node -v)"
echo "  npm  $(npm -v)"
[ -f package.json ] || { echo "  ✗ 当前目录不是仓库根（无 package.json）"; exit 1; }
echo "  ✓ 仓库结构正常"

# ---------- 1. 协议自适应补丁 ----------
echo
echo "[1/5] 应用协议自适应补丁 (connector.luau)"

PATCHER="$(mktemp /tmp/patch-connector.XXXXXX.mjs)"
cat > "$PATCHER" <<'PATCH_EOF'
import fs from "node:fs";
const FILE = process.argv[2];
let src = fs.readFileSync(FILE, "utf8");

const anchor = `local BridgeURL = getgenv().BridgeURL or ... or "localhost:16384"`;

if (src.includes("BridgeHttpBase")) {
  console.log("  已打过补丁，跳过");
  process.exit(0);
}
if (!src.includes(anchor)) {
  console.error("  未找到 BridgeURL 锚点");
  process.exit(1);
}

const helper = `${anchor}

--// Protocol Auto-Detect (Codespaces / HTTPS) \\--
-- BridgeURL 可直接填写 https://xxx.app.github.dev ，协议自动推导
local BridgeHttpBase, BridgeWsBase
do
    local raw = tostring(BridgeURL or "")
    raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
    raw = raw:gsub("/+$", "")
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

src = src.replace(anchor, helper);

const reps = [
  [`Url = "http://" .. BridgeURL,`,                              `Url = BridgeHttpBase,`],
  [`WebSocket.connect("ws://" .. BridgeURL)`,                    `WebSocket.connect(BridgeWsBase)`],
  [`Url = "http://" .. BridgeURL .. "/register",`,               `Url = BridgeHttpBase .. "/register",`],
  [`local pollUrl = "http://" .. BridgeURL .. "/poll"`,          `local pollUrl = BridgeHttpBase .. "/poll"`],
  [`Url = "http://" .. BridgeURL .. "/respond",`,                `Url = BridgeHttpBase .. "/respond",`],
  [`Url = "http://" .. BridgeURL .. "/script-sources",`,         `Url = BridgeHttpBase .. "/script-sources",`],
];

let n = 0;
for (const [a, b] of reps) {
  const c = src.split(a).length - 1;
  if (c === 0) { console.error("  未匹配到: " + a); process.exit(1); }
  src = src.split(a).join(b);
  n += c;
}

fs.writeFileSync(FILE, src);
console.log(`  ✓ 替换 ${n} 处硬编码协议`);
PATCH_EOF

[ -f connector.luau.bak ] || cp connector.luau connector.luau.bak
node "$PATCHER" "$ROOT/connector.luau" || { echo "  ✗ 补丁失败"; rm -f "$PATCHER"; exit 1; }
rm -f "$PATCHER"

# ---------- 2. 依赖 ----------
echo
echo "[2/5] 安装依赖"
if [ -d node_modules ] && [ -f node_modules/.package-lock.json ]; then
  echo "  node_modules 已存在，跳过"
else
  npm install --no-audit --no-fund 2>&1 | tail -6
fi

# ---------- 3. 编译 ----------
echo
echo "[3/5] 编译 TypeScript"
npm run build 2>&1 | tail -6
if [ ! -f dist/index.js ]; then
  echo "  ✗ 编译失败：dist/index.js 不存在"
  exit 1
fi
echo "  ✓ dist/index.js 已生成"

# ---------- 4. 启动 ----------
echo
echo "[4/5] 启动桥接服务"
mkdir -p logs

# 彻底清理旧实例，并等待端口真正释放
# 注意：不依赖 pgrep/pkill（精简环境可能缺失），直接用 /proc 扫描
kill_stale() {
  local pid cmd
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    pid="${f#/proc/}"; pid="${pid%/cmdline}"
    [ "$pid" = "$$" ] && continue
    cmd="$(tr '\0' ' ' < "$f" 2>/dev/null)"
    case "$cmd" in
      *"dist/index.js"*)
        echo "  停止旧实例 PID $pid"
        kill -9 "$pid" 2>/dev/null || true
        ;;
    esac
  done
}

kill_stale
for i in $(seq 1 20); do
  still=0
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    cmd="$(tr '\0' ' ' < "$f" 2>/dev/null)"
    case "$cmd" in *"dist/index.js"*) still=1;; esac
  done
  [ "$still" = "0" ] && break
  sleep 0.5
done

: > logs/server.log
nohup node dist/index.js > logs/server.log 2>&1 &
PID=$!
echo "$PID" > logs/server.pid
echo "  PID=$PID"

# 轮询等待服务就绪（最多 30 秒）
READY=0
for i in $(seq 1 60); do
  if curl -sS -m 2 -o /dev/null "http://127.0.0.1:${PORT}/api/status" 2>/dev/null; then
    READY=1
    break
  fi
  sleep 0.5
done

if [ "$READY" = "1" ]; then
  echo "  ✓ 服务已就绪（${PORT} 端口响应正常）"
  echo "  ---- 状态 ----"
  curl -sS -m 5 "http://127.0.0.1:${PORT}/api/status" | sed 's/^/  /'
  echo
else
  echo "  ✗ 服务未就绪，请检查 logs/server.log"
  tail -15 logs/server.log | sed 's/^/  /'
  exit 1
fi

# ---------- 5. 端口可见性 ----------
echo
echo "[5/5] 端口可见性"
if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
  if gh codespace ports visibility "$PORT:public" -c "$CODESPACE_NAME" >/dev/null 2>&1; then
    echo "  ✓ 已将 ${PORT} 设为 public"
  else
    echo "  ! 自动设置失败，请在 PORTS 面板手动设为 Public"
  fi
else
  echo "  ! 请手动设置：PORTS 面板 → 端口 ${PORT} → 右键 → Port Visibility → Public"
fi

# ---------- 连接信息 ----------
DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
if [ -n "${CODESPACE_NAME:-}" ]; then
  BASE="https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"
else
  BASE="http://localhost:${PORT}"
fi

echo
echo "============================================"
echo " 部署完成"
echo "============================================"
echo " 仪表盘   : ${BASE}/"
echo " 加载器   : ${BASE}/script.luau"
echo " 状态接口 : ${BASE}/api/status"
echo
echo " ── 在 Roblox 执行器里注入 ──"
echo "   getgenv().BridgeURL = \"${BASE#https://}\""
echo "   loadstring(game:HttpGet(\"${BASE}/script.luau\"))()"
echo
echo " 查看日志 : tail -f logs/server.log"
echo " 停止服务 : bash stop.sh   （或 kill \$(cat logs/server.pid)）"
echo " 重启服务 : bash codespaces-bootstrap.sh"
echo "============================================"
