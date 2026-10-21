#!/usr/bin/env bash
# ==========================================================
#  Roblox-MCP · GitHub Codespaces 一键部署（可整段粘贴）
# ==========================================================
set -u
PORT=16384
cd "${CODESPACE_VSCODE_FOLDER:-$PWD}" || exit 1
export COREPACK_ENABLE_STRICT=0

echo "[1/4] 打协议自适应补丁（Codespaces 必需：原版硬编码 http:// / ws://，在 https 下连不上）"
node --input-type=module - connector.luau <<'EOF'
import fs from "node:fs";
const FILE = process.argv[2];
let s = fs.readFileSync(FILE, "utf8");
const anchor = `local BridgeURL = getgenv().BridgeURL or ... or "localhost:16384"`;
if (s.includes("BridgeHttpBase")) { console.log("  已打过补丁，跳过"); process.exit(0); }
if (!s.includes(anchor)) { console.error("  找不到锚点"); process.exit(1); }
s = s.replace(anchor, `${anchor}
local BridgeHttpBase, BridgeWsBase
do
    local raw = tostring(BridgeURL or "")
    raw = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
    if raw:match("^https://") then
        BridgeHttpBase = raw; BridgeWsBase = raw:gsub("^https://", "wss://")
    elseif raw:match("^wss://") then
        BridgeWsBase = raw; BridgeHttpBase = raw:gsub("^wss://", "https://")
    elseif raw:match("^http://") then
        BridgeHttpBase = raw; BridgeWsBase = raw:gsub("^http://", "ws://")
    elseif raw:match("^ws://") then
        BridgeWsBase = raw; BridgeHttpBase = raw:gsub("^ws://", "http://")
    else
        BridgeHttpBase = "http://" .. raw; BridgeWsBase = "ws://" .. raw
    end
end`);
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
  if (!c) { console.error("  未匹配: " + a); process.exit(1); }
  s = s.split(a).join(b); n += c;
}
fs.writeFileSync(FILE, s);
console.log("  ✓ 替换 " + n + " 处硬编码协议");
EOF

echo "[2/4] 安装依赖 + 编译"
[ -d node_modules ] || npm install --no-audit --no-fund 2>&1 | tail -3
npm run build 2>&1 | tail -3

echo "[3/4] 启动服务"
mkdir -p logs
for f in /proc/[0-9]*/cmdline; do
  [ -r "$f" ] || continue
  p="${f#/proc/}"; p="${p%/cmdline}"; [ "$p" = "$$" ] && continue
  case "$(tr '\0' ' ' < "$f" 2>/dev/null)" in *dist/index.js*) kill -9 "$p" 2>/dev/null;; esac
done
sleep 1
: > logs/server.log
nohup node dist/index.js > logs/server.log 2>&1 &
echo "$!" > logs/server.pid
for i in $(seq 1 60); do
  curl -sS -m 2 -o /dev/null "http://127.0.0.1:$PORT/api/status" 2>/dev/null && break
  sleep 0.5
done
curl -sS -m 5 "http://127.0.0.1:$PORT/api/status" | sed 's/^/  /'

echo "[4/4] 设置端口可见性"
if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
  gh codespace ports visibility "$PORT:public" -c "$CODESPACE_NAME" >/dev/null 2>&1 \
    && echo "  ✓ 已设为 public" \
    || echo "  ! 自动失败，请到 PORTS 面板手动设为 Public"
else
  echo "  ! 请到 PORTS 面板 → 端口 $PORT → 右键 → Port Visibility → Public"
fi

BASE="https://${CODESPACE_NAME:-localhost}-$PORT.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
echo
echo "=========================================="
echo " 仪表盘 : $BASE/"
echo " 加载器 : $BASE/script.luau"
echo "=========================================="
echo " 执行器里注入（注意 BridgeURL 必须带 https:// 前缀）："
echo "   getgenv().BridgeURL = \"$BASE\""
echo "   loadstring(game:HttpGet(\"$BASE/script.luau\"))()"
echo "=========================================="