# vps-safe-proxy-deploy

个人 VPS 一键安全伪装代理部署项目。目标是在新的 Debian/Ubuntu VPS 上用一行命令部署 Reality Vision、Hysteria2、XHTTP/Caddy 三套方案，并把客户端信息只写入受限权限的凭据文件。

> 真实安装只支持 Debian 11/12、Ubuntu 22.04/24.04 与 systemd。Alpine/OpenRC 暂不支持真实安装。

## 通用一行安装与自动检测

普通 Debian/Ubuntu VPS 可直接运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all
```

脚本会先检测 OS/init system。只有在需要生成客户端导出信息时，才会检查 `PUBLIC_HOST`。如果未提供 `PUBLIC_HOST`，会按顺序自动尝试：

1. `https://api.ipify.org`
2. `https://ifconfig.co`
3. `https://icanhazip.com`

也可以手动覆盖：

```bash
PUBLIC_HOST=1.2.3.4 \
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all
```

NAT 机器示例：

```bash
NAT_MODE=true \
REALITY_EXTERNAL_PORT=24443 \
XHTTP_EXTERNAL_PORT=22053 \
INSTALL_HY2=false \
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all
```

NAT 模式只影响客户端导出的端口。服务商面板或上级 NAT 设备仍需要手动配置端口转发。

## 什么叫通用脚本

这里的通用不是指在任何系统上都强行安装三套协议，而是：

1. 自动识别 OS、init system、容器/虚拟化、端口和 NAT 状态。
2. 支持的 Debian/Ubuntu + systemd 环境完整安装。
3. 部分支持的环境自动降级，例如 TCP-only NAT 可跳过 Hysteria2。
4. 不支持的环境安全退出，仍允许 `--dry-run` 预览。
5. 不假装成功，不乱改系统，不写入不该写的真实路径。

## 平台能力矩阵

可以先运行只读检测，不安装软件、不生成凭据、不重启服务：

```bash
./install.sh detect
```

通过 bootstrap 也可以运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) detect
```

`detect` 会输出：

- OS 名称和版本、CPU 架构、root 状态。
- init system：`systemd`、`OpenRC` 或 `unknown`。
- 虚拟化/容器：LXC、Docker、KVM 或 unknown。
- 是否支持 systemd、是否可能支持 BBR。
- `curl`、`unzip`、`openssl` 是否存在。
- TCP `443`、TCP `2053` 是否被占用。
- UDP `8443` 本地监听状态和外部映射未知提示。
- `NAT_MODE` 当前值。
- `PUBLIC_HOST` 自动检测结果，失败时提示如何手动设置。
- Reality Vision、Hysteria2、XHTTP + Caddy、BBR 的当前可用状态。

Alpine/OpenRC 只能 dry-run：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all --dry-run
```

无 UDP 映射的机器建议跳过 HY2：

```bash
INSTALL_HY2=false bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all --dry-run
```

## Alpine LXC / NAT / 无 UDP 测试

- Alpine/OpenRC 不支持真实安装，只支持 `--dry-run`。
- IPv4 NAT 且无 UDP 映射的机器应使用 `INSTALL_HY2=false`。
- TCP-only NAT 机器只能测试 Reality/XHTTP 的端口导出和 dry-run 渲染。
- 完整三套真实安装必须使用 Debian/Ubuntu + systemd + TCP/UDP 可用的临时 VPS。

示例：

```bash
PUBLIC_HOST="$(curl -4fsS https://api.ipify.org)" \
NAT_MODE=true \
INSTALL_HY2=false \
REALITY_EXTERNAL_PORT=24443 \
XHTTP_EXTERNAL_PORT=22053 \
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all --dry-run
```

## 安装开关

`all` 模式会读取以下开关：

```text
INSTALL_REALITY=true
INSTALL_HY2=true
INSTALL_XHTTP=true
```

例如 `INSTALL_HY2=false` 会完全跳过 Hysteria2：不渲染 HY2 服务端配置，不生成 HY2 客户端 URI，只在凭据文件里记录跳过原因。

## 方案目标

| 命令 | 默认端口 | 目标 |
| --- | --- | --- |
| `./install.sh reality` | `443/tcp` | VLESS + REALITY + XTLS Vision + uTLS fingerprint + BBR |
| `./install.sh hy2` | `8443/udp` | Hysteria2 + TLS/ACME + HTTP/3 Masquerade + Salamander Obfs |
| `./install.sh xhttp` | `2053/tcp` | VLESS + XHTTP + Caddy 真网站伪装 + CDN/优选节点 |
| `./install.sh bbr` | 无 | 检测并尽量开启 BBR，不支持则跳过 |

## 支持命令

```bash
./install.sh all
./install.sh reality
./install.sh hy2
./install.sh xhttp
./install.sh bbr
./install.sh detect
./install.sh status
./install.sh uninstall
```

测试和预览：

```bash
./install.sh all --dry-run
./install.sh all --test-mode
./install.sh reality --dry-run
./install.sh hy2 --dry-run
./install.sh xhttp --dry-run
```

`--dry-run` 只渲染配置到 `tests/tmp` 或临时目录，不写真实系统目录。  
`--test-mode` 会优先使用 `tests/mocks` 里的 mock 命令，并把真实路径重定向到 `tests/tmp`。

## Dry-Run 输出路径

`--dry-run` 和 `--test-mode` 下，写入路径必须保持在 `tests/tmp` 内。默认路径如下：

```text
ROOT_DIR=tests/tmp/root
ETC_DIR=tests/tmp/etc
LOG_DIR=tests/tmp/log
CREDENTIALS_FILE=tests/tmp/root/vps-oneclick/credentials.txt
XRAY_CONFIG_FILE=tests/tmp/etc/xray/config.json
HY2_CONFIG_FILE=tests/tmp/etc/hysteria/hysteria-server.yaml
CADDY_CONFIG_FILE=tests/tmp/etc/caddy/Caddyfile
BACKUP_DIR=tests/tmp/backups
```

如果用户把这些变量重定向到 `tests/tmp` 之外，安装器会直接退出，避免误写真实系统目录。

## 客户端信息

所有 UUID、密码、私钥、节点链接和客户端片段只能保存到：

```text
/root/vps-oneclick/credentials.txt
```

权限必须为 `600`。终端只会提示凭据文件路径，不会直接打印完整节点链接。

## XHTTP/CDN 说明

XHTTP 默认由 Caddy 对外提供 HTTPS 网站。只有随机路径会反代到本机 Xray XHTTP，Xray XHTTP 只能监听 `127.0.0.1` 内网端口，不能直接暴露公网。

使用 Cloudflare 或优选 IP 时，客户端地址可以填写优选 IP，但 Host/SNI 必须保持 `XHTTP_DOMAIN`。

如果 `XHTTP_DOMAIN` 为空，Caddy 会生成无域名降级配置，伪装完整度会下降。生产环境建议为 XHTTP/Caddy 准备真实域名。

## Hysteria2 证书与 UDP

提供 `HY2_DOMAIN` 和 `EMAIL` 时会生成 ACME 模式配置。没有 `HY2_DOMAIN` 或没有 `EMAIL` 时会使用自签证书，伪装完整度会下降。

Hysteria2 默认使用 UDP `8443`。脚本会提示 UDP 可用性无法完全本地确认，不会假装 UDP 一定可用。

## 来源

- Xray-core：XTLS/Xray-core GitHub release。
- Hysteria2：apernet/hysteria GitHub release。
- Caddy：官方 Cloudsmith Caddy stable apt 仓库。

不安装 Web 面板，不开放管理端口。

## 防火墙和 NAT

只有 `ENABLE_FIREWALL=true` 时才会尝试使用 `ufw allow` 放行所需端口，不会清空现有规则。`ufw` 不存在时只提示 warning，不中断安装。

`NAT_MODE=true` 时客户端导出使用 `*_EXTERNAL_PORT`，但仍需要在服务商面板或上级 NAT 设备中配置端口转发。

## 测试

```bash
bash -n bootstrap.sh install.sh lib/*.sh
shellcheck bootstrap.sh install.sh lib/*.sh
shfmt -d bootstrap.sh install.sh lib/*.sh
bats tests/bats
```

GitHub Actions 会在 `push` 和 `pull_request` 时运行语法、格式、ShellCheck、Bats 和安全扫描。

## GitHub 部署

如果本机已安装并登录 GitHub CLI：

```bash
gh repo create tbckmust-jpg/vps-safe-proxy-deploy --public --source=. --remote=origin --push
```

如果尚未登录：

```bash
gh auth login
```

也可以先在 GitHub 网页创建空仓库，然后执行：

```bash
git remote add origin https://github.com/tbckmust-jpg/vps-safe-proxy-deploy.git
git branch -M main
git push -u origin main
```
