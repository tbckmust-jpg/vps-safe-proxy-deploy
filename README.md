# vps-safe-proxy-deploy

个人 VPS 一键部署项目，目标是在新 VPS 上用一行命令安装三套完整安全伪装代理方案，并把所有客户端信息只写入受限权限的凭据文件。

当前提交建立项目骨架、测试框架、模板边界和 CI。后续实现应继续保持模块化，不把协议逻辑堆进 `install.sh`。

## 一行安装

默认 main 分支：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all
```

未来稳定版：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/v0.1.0/bootstrap.sh) all
```

带域名：

```bash
PUBLIC_HOST=1.2.3.4 \
HY2_DOMAIN=hy2.example.com \
XHTTP_DOMAIN=cdn.example.com \
EMAIL=me@example.com \
bash <(curl -fsSL https://raw.githubusercontent.com/tbckmust-jpg/vps-safe-proxy-deploy/main/bootstrap.sh) all
```

## 方案目标

| 命令 | 默认端口 | 目标 |
| --- | --- | --- |
| `./install.sh reality` | `443/tcp` | VLESS + REALITY + XTLS Vision + uTLS fingerprint + BBR |
| `./install.sh hy2` | `8443/udp` | Hysteria2 + TLS/ACME + HTTP/3 Masquerade + Salamander Obfs |
| `./install.sh xhttp` | `2053/tcp` | VLESS + XHTTP + Caddy 真网站伪装 + CDN/优选节点 |
| `./install.sh bbr` | 无 | 检测并尽量开启 BBR，不支持则跳过 |

`./install.sh all` 会依次执行 BBR、Reality Vision、Hysteria2、XHTTP/Caddy。

## 支持命令

```bash
./install.sh all
./install.sh reality
./install.sh hy2
./install.sh xhttp
./install.sh bbr
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

真实安装逻辑已经实现，但必须先在 GitHub Actions 或 Linux 测试环境保持 CI 全绿，再进入真实 VPS 安装测试。

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

三套方案 dry-run 会生成：

```text
tests/tmp/etc/xray/xray-reality-vision.json
tests/tmp/etc/hysteria/hysteria-server.yaml
tests/tmp/etc/xray/xray-xhttp.json
tests/tmp/etc/caddy/Caddyfile
tests/tmp/root/vps-oneclick/site/index.html
tests/tmp/render/hysteria-client.yaml
tests/tmp/root/vps-oneclick/credentials.txt
```

如果用户把这些变量重定向到 `tests/tmp` 之外，安装器会直接退出，避免误写真实系统目录。

`--test-mode` 会把路径重定向到 `tests/tmp` 并优先使用 `tests/mocks` 中的命令，因此可以覆盖真实安装分支而不改真实系统。

## 配置文件

复制示例文件后再按需修改：

```bash
cp config.env.example config.env
```

`config.env` 不得提交到 GitHub。缺少 `PUBLIC_HOST` 时，安装器必须给出明确提示。没有 Hysteria2 域名时允许自签证书，但伪装完整度会下降。

## 客户端信息

所有 UUID、密码、私钥、节点链接和客户端片段只能保存到：

```text
/root/vps-oneclick/credentials.txt
```

权限必须为 `600`。终端只会提示 `配置已生成，请查看 ...`，不会直接打印完整节点链接。

Reality Vision 的 dry-run 可以使用 fallback 逻辑生成 private/public key 占位值。真实安装阶段会先安装 Xray-core，再使用 `xray x25519` 生成 Reality privateKey/publicKey，并在 `xray test -config` 通过后再重启服务。Xray-core 通过 XTLS/Xray-core GitHub release 下载。

## XHTTP/CDN 说明

XHTTP 默认由 Caddy 对外提供 HTTPS 网站，只有随机路径会反代到本机 Xray XHTTP。Xray XHTTP 只能监听 `127.0.0.1` 内网端口，不能直接暴露公网。

使用 Cloudflare 或优选 IP 时，客户端地址可以填写优选 IP，但 Host/SNI 必须保持 `XHTTP_DOMAIN`。

如果 `XHTTP_DOMAIN` 为空，Caddy 会生成无域名降级配置并只在指定端口提供普通站点，伪装完整度会下降。生产环境建议为 XHTTP/Caddy 准备真实域名。

## Hysteria2 证书

提供 `HY2_DOMAIN` 和 `EMAIL` 时会生成 ACME 模式配置。没有 `HY2_DOMAIN` 或没有 `EMAIL` 时会使用自签证书，伪装完整度会下降。Hysteria2 通过 apernet/hysteria GitHub release 下载。

## Caddy 来源

Caddy 真实安装使用官方 Cloudsmith Caddy stable apt 仓库，不安装 Web 面板。

## 防火墙和 NAT

只有 `ENABLE_FIREWALL=true` 时才会尝试使用 `ufw allow` 放行所需端口，不会清空现有规则。`ufw` 不存在时只提示 warning，不中断安装。

`NAT_MODE=true` 时客户端导出使用 `*_EXTERNAL_PORT`，但还需要在 VPS 服务商面板或上级 NAT 设备中配置端口转发。

## 测试

```bash
bash -n bootstrap.sh install.sh lib/*.sh
shellcheck bootstrap.sh install.sh lib/*.sh
shfmt -d bootstrap.sh install.sh lib/*.sh
bats tests/bats
```

GitHub Actions 会在 `push` 和 `pull_request` 时运行语法、格式、ShellCheck、Bats 和安全扫描。

如果当前本机没有 `bash`、`shellcheck`、`shfmt` 或 `bats`，不要为了 dry-run 阶段去安装第三方脚本；先提交代码，让 GitHub Actions 或 Linux 环境运行完整检查。

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
