# Ubuntu 24.04 VMess 一键部署

适用于 Ubuntu 24.04 64 位服务器。脚本会安装官方 Xray、启用 BBR 网络加速、自动生成 UUID、创建 VMess TCP 配置、启动服务，并输出可导入 v2rayN/v2rayNG 的 `vmess://` 链接和终端二维码。

## 一键安装

SSH 登录服务器后，粘贴下面的命令并按回车：

```bash
curl -fsSL https://raw.githubusercontent.com/wkx176617-sys/vmess-oneclick/main/install.sh | sudo bash
```

部署完成后，可以复制终端输出的 `vmess://` 链接，或直接使用 v2rayN、v2rayNG、Shadowrocket（小火箭）扫描终端二维码导入。

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

## 已部署服务器仅开启 BBR

如果 VMess 已经部署完成，不要重新运行主安装脚本。使用下面的命令只开启 BBR，不会修改 UUID、端口或 Xray 配置：

```bash
curl -fsSL https://raw.githubusercontent.com/wkx176617-sys/vmess-oneclick/main/enable-bbr.sh | sudo bash
```

## 兼容参数

- 协议：VMess
- 分享格式：`vmess://` Base64 JSON，配置版本 `v=2`
- 传输：TCP
- alterId：0
- 加密：auto
- TLS：关闭

已针对以下客户端使用通用字段生成链接和二维码：

- v2rayN V3 系列
- 新版 v2rayN
- v2rayNG
- Shadowrocket（小火箭）

`alterId=0` 使用 VMess AEAD，因此 v2rayN V3 所调用的 V2Ray/Xray 核心需要支持 VMess AEAD（V2Ray Core 4.28.1 或更高版本）。年代更早的非 AEAD 核心不在兼容范围内。

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
