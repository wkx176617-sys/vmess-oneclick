# Ubuntu 24.04 VMess 一键部署

适用于 Ubuntu 24.04 64 位服务器。脚本会安装官方 Xray、启用 BBR 网络加速、自动生成 UUID、创建 VMess TCP 配置、启动服务，并输出可导入 v2rayN/v2rayNG 的 `vmess://` 链接。

## 一键安装

SSH 登录服务器后，粘贴下面的命令并按回车：

```bash
curl -fsSL https://raw.githubusercontent.com/wkx176617-sys/vmess-oneclick/main/install.sh | sudo bash
```

部署完成后，复制终端输出的 `vmess://` 链接，导入 v2rayN、v2rayNG 或其他兼容客户端。

还需要在云服务商控制台的安全组中开放 TCP `10086` 端口。

## 自定义端口

默认端口是 `10086`。如需使用其他端口：

```bash
curl -fsSL https://raw.githubusercontent.com/wkx176617-sys/vmess-oneclick/main/install.sh | sudo VMESS_PORT=23456 bash
```

## 查看状态和日志

```bash
sudo systemctl status xray
sudo journalctl -u xray -n 100 --no-pager
```

检查 BBR 是否启用：

```bash
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

正常结果分别为 `bbr` 和 `fq`。

## 兼容参数

- 协议：VMess
- 传输：TCP
- alterId：0
- 加密：auto
- TLS：关闭

## 安全说明

- 脚本仅支持 Ubuntu 24.04 x86_64。
- 如果服务器已有 Xray 配置，脚本会先在同一目录创建带时间戳的备份。
- BBR 配置保存在 `/etc/sysctl.d/99-vmess-bbr.conf`；已有同名配置时会先创建带时间戳的备份。
- 脚本不会自动启用 UFW；如果 UFW 已启用，只会添加当前 VMess 端口。
- VMess TCP 适合简单、兼容性优先的部署。对抗干扰或长期公网使用时，建议改用带传输层安全保护的方案。
- 请遵守服务器所在地及使用所在地的法律法规和服务条款。

## 软件来源

Xray 通过 XTLS 官方安装脚本安装：

- <https://github.com/XTLS/Xray-install>
- <https://github.com/XTLS/Xray-core>
