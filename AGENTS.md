# AGENTS.md

本仓库是个人 VPS 安全伪装代理的一键部署项目。任何自动化代理或人工维护者改动时，都必须优先保持安全、可测试、可回滚。

## 强制规则

- 所有功能都必须支持 `--dry-run` 和 `--test-mode`。
- 所有真实系统路径都必须可通过变量重定向到 `tests/tmp`，包括 `ROOT_DIR`、`ETC_DIR`、`LOG_DIR`、`CREDENTIALS_FILE`、`XRAY_CONFIG_FILE`、`HY2_CONFIG_FILE`、`CADDY_CONFIG_FILE`、`BACKUP_DIR`。
- `--dry-run` 和 `--test-mode` 的输出路径必须保持在 `tests/tmp` 内；如果变量指向真实系统目录，必须退出。
- 第二阶段只允许实现 dry-run/test-mode 渲染和 mock 测试，不得真实安装 Xray、Hysteria2、Caddy。
- 不得提交密钥、密码、UUID、节点链接、证书、日志或真实配置文件。
- 不得默认安装 Web 面板。
- 不得默认开放管理端口。
- 不得默认清空防火墙，只允许放行部署需要的端口。
- 不得在终端打印完整节点链接。
- 生成的节点链接和客户端配置只能写入 `CREDENTIALS_FILE`，生产默认路径为 `/root/vps-oneclick/credentials.txt`，权限必须为 `600`。
- 修改旧配置前必须备份。
- 服务测试、配置测试或重启失败时必须回滚。
- Alpine/OpenRC 暂不支持，只能提示退出，不能乱写 systemd 服务。

## 变更同步

新增参数或行为时，必须同步更新：

- `README.md`
- `config.env.example`
- 对应 `templates/`
- 对应 `tests/bats/`

## 验收要求

每次修改后必须尽量通过：

- `bash -n bootstrap.sh install.sh lib/*.sh`
- `shellcheck bootstrap.sh install.sh lib/*.sh`
- `shfmt -d bootstrap.sh install.sh lib/*.sh`
- `bats tests/bats`

如果某个工具本机缺失，必须在最终说明里明确写出未运行原因。
