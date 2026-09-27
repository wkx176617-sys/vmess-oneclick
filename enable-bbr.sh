#!/usr/bin/env bash

set -Eeuo pipefail

readonly BBR_CONFIG="/etc/sysctl.d/99-vmess-bbr.conf"

fail() {
  printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
  fail "请使用 sudo 运行此脚本。"
fi

if [[ -f "$BBR_CONFIG" ]]; then
  cp -a "$BBR_CONFIG" "${BBR_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
fi

modprobe tcp_bbr 2>/dev/null || fail "当前内核不支持 BBR。"

cat >"$BBR_CONFIG" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl --system >/dev/null

[[ "$(sysctl -n net.ipv4.tcp_congestion_control)" == "bbr" ]] || fail "BBR 未成功启用。"
[[ "$(sysctl -n net.core.default_qdisc)" == "fq" ]] || fail "fq 队列规则未成功启用。"

printf '\033[1;32m[完成]\033[0m BBR 已启用，当前拥塞控制算法：%s\n' \
  "$(sysctl -n net.ipv4.tcp_congestion_control)"
