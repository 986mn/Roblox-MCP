#!/usr/bin/env bash
# ============================================================
#  Roblox-MCP · Codespaces postCreate 脚本
#  容器首次创建时执行：打补丁 → 装依赖 → 编译
#  幂等，可重复执行。
# ============================================================
set -u

# 进入仓库根目录
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"

# 避免 corepack 依据 packageManager 字段强制切换包管理器
export COREPACK_ENABLE_STRICT=0

echo "=========================================="
echo " Roblox-MCP · Codespaces 初始化"
echo " 仓库: $ROOT"
echo "=========================================="

# ---------- 1. 协议自适应补丁 ----------
echo
echo "[1/3] 应用协议自适应补丁"
if [ -f .devcontainer/patch-connector.mjs ]; then
  # 保留一份原始文件备份
  [ -f connector.luau.bak ] || cp connector.luau connector.luau.bak 2>/dev/null || true
  node .devcontainer/patch-connector.mjs "$ROOT/connector.luau" || {
    echo "  ✗ 补丁失败（服务仍可启动，但 Roblox 客户端可能连不上）"
  }
else
  echo "  ! 找不到 .devcontainer/patch-connector.mjs"
fi

# ---------- 2. 依赖 ----------
echo
echo "[2/3] 安装依赖"
if [ -d node_modules ] && [ -f node_modules/.package-lock.json ]; then
  echo "  node_modules 已存在，跳过"
else
  npm install --no-audit --no-fund 2>&1 | tail -5
fi

# ---------- 3. 编译 ----------
echo
echo "[3/3] 编译 TypeScript"
npm run build 2>&1 | tail -5

if [ -f dist/index.js ]; then
  echo "  ✓ dist/index.js 已生成"
else
  echo "  ✗ 编译失败：dist/index.js 不存在"
  exit 1
fi

echo
echo "=========================================="
echo " 初始化完成"
echo "=========================================="