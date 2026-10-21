#!/usr/bin/env bash
# 停止 Roblox-MCP 桥接服务（不依赖 pgrep/pkill）
set -u

ROOT="${CODESPACE_VSCODE_FOLDER:-$(pwd)}"
cd "$ROOT" 2>/dev/null || exit 1

stopped=0

# 1) 优先按记录的 PID 停止
if [ -f logs/server.pid ]; then
  PID="$(cat logs/server.pid 2>/dev/null || true)"
  if [ -n "${PID:-}" ] && [ -d "/proc/$PID" ]; then
    echo "停止 PID $PID"
    kill -9 "$PID" 2>/dev/null && stopped=1
  fi
  rm -f logs/server.pid
fi

# 2) 兜底：扫描 /proc，清理所有 dist/index.js 实例
for f in /proc/[0-9]*/cmdline; do
  [ -r "$f" ] || continue
  pid="${f#/proc/}"; pid="${pid%/cmdline}"
  [ "$pid" = "$$" ] && continue
  cmd="$(tr '\0' ' ' < "$f" 2>/dev/null)"
  case "$cmd" in
    *"dist/index.js"*)
      echo "停止残留实例 PID $pid"
      kill -9 "$pid" 2>/dev/null && stopped=1
      ;;
  esac
done

if [ "$stopped" = "1" ]; then
  echo "✓ 服务已停止"
else
  echo "没有正在运行的服务"
fi