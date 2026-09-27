#!/usr/bin/env bash

set -Eeuo pipefail

readonly DEFAULT_PORT="10086"
readonly XRAY_CONFIG="/usr/local/etc/xray/config.json"
readonly XRAY_INSTALL_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

info() {
  printf '\033[1;34m[信息]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[完成]\033[0m %s\n' "$*"
}

fail() {
  printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
  fail "请使用 sudo 运行：curl -fsSL <安装链接> | sudo bash"
fi

if [[ ! -r /etc/os-release ]]; then
  fail "无法识别操作系统。本脚本仅支持 Ubuntu 24.04。"
fi

# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || fail "当前系统不是 Ubuntu。"
[[ "${VERSION_ID:-}" == "24.04" ]] || fail "当前版本是 ${VERSION_ID:-未知}，仅支持 Ubuntu 24.04。"

case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail "当前架构是 $(uname -m)，此仓库要求 Ubuntu 24.04 64 位 x86_64。" ;;
esac

PORT="${VMESS_PORT:-$DEFAULT_PORT}"
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  fail "端口必须是 1024 到 65535 之间的数字。"
fi

info "安装基础组件……"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates >/dev/null

info "启用系统时间同步……"
timedatectl set-ntp true || true

info "从 XTLS 官方仓库安装 Xray……"
INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL "$XRAY_INSTALL_URL" -o "$INSTALLER"
bash "$INSTALLER" install

[[ -x /usr/local/bin/xray ]] || fail "Xray 安装失败。"
UUID="$(/usr/local/bin/xray uuid)"
[[ -n "$UUID" ]] || fail "无法生成 UUID。"

install -d -m 755 "$(dirname "$XRAY_CONFIG")"
if [[ -f "$XRAY_CONFIG" ]]; then
  BACKUP="${XRAY_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
  cp -a "$XRAY_CONFIG" "$BACKUP"
  info "原配置已备份到 $BACKUP"
fi

write_config() {
  local user_key="$1"
  cat >"$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "${user_key}": [
          {
            "id": "${UUID}",
            "alterId": 0
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
  chmod 600 "$XRAY_CONFIG"
}

# Xray 的稳定版长期使用 clients；新配置格式也可能使用 users。
# 先采用兼容性最广的写法，配置测试不通过时自动切换。
write_config "clients"
if ! /usr/local/bin/xray run -test -c "$XRAY_CONFIG" >/dev/null 2>&1; then
  write_config "users"
fi
/usr/local/bin/xray run -test -c "$XRAY_CONFIG" >/dev/null 2>&1 || fail "生成的 Xray 配置未通过检查。"

info "启动 Xray 服务……"
systemctl enable xray >/dev/null
systemctl restart xray
systemctl is-active --quiet xray || fail "Xray 服务启动失败，请运行 journalctl -u xray -n 100 查看日志。"

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q '^Status: active'; then
  ufw allow "${PORT}/tcp" >/dev/null
  info "已在 UFW 中开放 TCP ${PORT} 端口。"
fi

PUBLIC_IP="$(curl -4 -fsS --max-time 8 https://api.ipify.org || true)"
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
[[ -n "$PUBLIC_IP" ]] || PUBLIC_IP="请填写服务器公网IP"

VMESS_JSON="$(printf '{"v":"2","ps":"Ubuntu-VMess","add":"%s","port":"%s","id":"%s","aid":"0","scy":"auto","net":"tcp","type":"none","host":"","path":"","tls":""}' "$PUBLIC_IP" "$PORT" "$UUID")"
VMESS_LINK="vmess://$(printf '%s' "$VMESS_JSON" | base64 -w 0)"

printf '\n'
success "VMess 已部署并启动"
printf '%s\n' "----------------------------------------"
printf '服务器地址：%s\n' "$PUBLIC_IP"
printf '端口：      %s\n' "$PORT"
printf 'UUID：      %s\n' "$UUID"
printf 'alterId：   0\n'
printf '传输协议：  TCP\n'
printf 'TLS：       关闭\n'
printf '%s\n' "----------------------------------------"
printf 'V2Ray 导入链接：\n%s\n' "$VMESS_LINK"
printf '%s\n' "----------------------------------------"
printf '请确认云服务商安全组已开放 TCP %s 端口。\n' "$PORT"
