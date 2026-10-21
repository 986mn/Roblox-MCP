#!/usr/bin/env bash
# ============================================================
#  Roblox-MCP · Codespaces 保活脚本
#
#  作用：在 Codespace 里持续产生「活动」，避免空闲超时休眠，
#        让 Roblox-MCP 桥接服务保持在线。
#
#  用法：
#      bash keepalive.sh            # 前台运行（Ctrl+C 停止）
#      bash keepalive.sh --daemon   # 后台运行
#      bash keepalive.sh --stop     # 停止后台保活
#      bash keepalive.sh --status   # 查看状态
#
#  保活手段（三重）：
#    1. 终端心跳输出  —— 让终端持续有活动
#    2. 本地 HTTP 探活 —— 定期访问桥接服务 /api/status
#    3. 外部探测      —— 定期访问公网转发地址（若可用）
#
#  注意：Codespace 有 12 小时硬性生存期上限，无法绕过，
#        到点必须重启。本脚本只解决「空闲休眠」。
# ============================================================
set -u

# 解析脚本自身真实位置（兼容相对路径/绝对路径/symlink）
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT="$SCRIPT_DIR"
cd "$ROOT" || exit 1

PORT=16384
LOG_DIR="$ROOT/logs"
PID_FILE="$LOG_DIR/keepalive.pid"
LOG_FILE="$LOG_DIR/keepalive.log"
INTERVAL="${KEEPALIVE_INTERVAL:-240}"   # 秒，默认 4 分钟

mkdir -p "$LOG_DIR"

# ---------- 子命令 ----------
case "${1:-}" in
  --stop)
    if [ -f "$PID_FILE" ] && [ -d "/proc/$(cat "$PID_FILE" 2>/dev/null)" ]; then
      PID="$(cat "$PID_FILE")"
      kill -9 "$PID" 2>/dev/null && echo "✓ 已停止保活 (PID $PID)"
    else
      echo "没有正在运行的保活进程"
    fi
    rm -f "$PID_FILE"
    exit 0
    ;;
  --status)
    if [ -f "$PID_FILE" ] && [ -d "/proc/$(cat "$PID_FILE" 2>/dev/null)" ]; then
      echo "✓ 保活运行中 (PID $(cat "$PID_FILE"))"
      echo "--- 最近日志 ---"
      tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    else
      echo "保活未运行"
    fi
    exit 0
    ;;
  --daemon)
    # 若已有实例在跑，先停掉
    if [ -f "$PID_FILE" ] && [ -d "/proc/$(cat "$PID_FILE" 2>/dev/null)" ]; then
      kill -9 "$(cat "$PID_FILE")" 2>/dev/null
      sleep 0.5
    fi
    # 用 setsid 完全脱离当前会话，避免随终端关闭而退出
    if command -v setsid >/dev/null 2>&1; then
      setsid nohup bash "$SCRIPT_PATH" </dev/null >/dev/null 2>&1 &
    else
      nohup bash "$SCRIPT_PATH" </dev/null >/dev/null 2>&1 &
    fi
    sleep 2
    if [ -f "$PID_FILE" ] && [ -d "/proc/$(cat "$PID_FILE" 2>/dev/null)" ]; then
      echo "✓ 保活已在后台启动 (PID $(cat "$PID_FILE"))"
      echo "  日志: $LOG_FILE"
    else
      echo "! 启动异常，请检查 $LOG_FILE"
    fi
    exit 0
    ;;
esac

# ---------- 计算外部地址 ----------
DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
if [ -n "${CODESPACE_NAME:-}" ]; then
  EXTERNAL_URL="https://${CODESPACE_NAME}-${PORT}.${DOMAIN}/api/status"
else
  EXTERNAL_URL=""
fi

echo "=========================================="
echo " Roblox-MCP · 保活启动"
echo " 间隔: ${INTERVAL}s"
echo " 本地: http://127.0.0.1:${PORT}/api/status"
[ -n "$EXTERNAL_URL" ] && echo " 外部: $EXTERNAL_URL"
echo "=========================================="
echo " 按 Ctrl+C 停止"

# 记录本进程 PID（前台运行时也写，便于 --stop）
echo $$ > "$PID_FILE"

cleanup() {
  echo
  echo "保活已停止"
  rm -f "$PID_FILE"
  exit 0
}
trap cleanup INT TERM

TICK=0
while true; do
  TICK=$((TICK + 1))
  TS="$(date '+%Y-%m-%d %H:%M:%S')"

  # 手段 1：终端心跳（产生终端活动）
  echo "[$TS] keepalive #${TICK}"

  # 手段 2：本地探活（同时确认桥接服务存活）
  LOCAL_OK="no"
  if curl -sS -m 5 -o /dev/null "http://127.0.0.1:${PORT}/api/status" 2>/dev/null; then
    LOCAL_OK="yes"
  fi

  # 手段 3：外部探测（若地址可用）
  EXT_OK="-"
  if [ -n "$EXTERNAL_URL" ]; then
    if curl -sS -m 8 -o /dev/null "$EXTERNAL_URL" 2>/dev/null; then
      EXT_OK="yes"
    else
      EXT_OK="no"
    fi
  fi

  # 若桥接服务不在了，尝试自动拉起
  RESTARTED=""
  if [ "$LOCAL_OK" = "no" ] && [ -f "$ROOT/dist/index.js" ]; then
    # 先清理可能存在的僵尸实例，避免重复拉起导致 relay 残留
    for f in /proc/[0-9]*/cmdline; do
      [ -r "$f" ] || continue
      p="${f#/proc/}"; p="${p%/cmdline}"
      [ "$p" = "$$" ] && continue
      c="$(tr '\0' ' ' < "$f" 2>/dev/null)"
      case "$c" in *"dist/index.js"*) kill -9 "$p" 2>/dev/null || true ;; esac
    done
    sleep 1
    setsid nohup node "$ROOT/dist/index.js" >> "$LOG_DIR/server.log" 2>&1 &
    # 等待其真正就绪，避免下次探活时误判为失败而再次拉起
    for _ in $(seq 1 20); do
      curl -sS -m 2 -o /dev/null "http://127.0.0.1:${PORT}/api/status" 2>/dev/null && break
      sleep 0.5
    done
    RESTARTED=" (已自动重启桥接服务)"
  fi

  echo "[$TS] local=$LOCAL_OK external=$EXT_OK${RESTARTED}" >> "$LOG_FILE"

  sleep "$INTERVAL"
done