#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

@test "sensitive files are ignored" {
  for pattern in \
    'config.env' '*.env' 'credentials.txt' '*.key' '*.pem' '*.crt' '*.log' \
    'backups/' 'tmp/' 'tests/tmp/'; do
    grep -Fxq "$pattern" "$REPO_ROOT/.gitignore"
  done
}

@test "terminal output does not print full node links" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com \
    bash "$REPO_ROOT/install.sh" all --dry-run --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" != *"://"* ]]
  [[ "$output" == *"credentials generated; view"* ]]
}

@test "credentials are written only to the redirected credentials file with 600 mode in test mode" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -eq 0 ]

  [ -f "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
  [ "$(stat -c '%a' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt")" = "600" ]
}

@test "XHTTP Xray listener is internal-only" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 XHTTP_DOMAIN=cdn.example.com \
    bash "$REPO_ROOT/install.sh" xhttp --dry-run --test-mode
  [ "$status" -eq 0 ]

  grep -q '"listen": "127.0.0.1"' "$REPO_ROOT/tests/tmp/etc/xray/xray-xhttp.json"
  grep -q 'reverse_proxy 127.0.0.1:' "$REPO_ROOT/tests/tmp/etc/caddy/Caddyfile"
}

@test "dry-run writes generated artifacts only under tests tmp" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com \
    bash "$REPO_ROOT/install.sh" all --dry-run --test-mode
  [ "$status" -eq 0 ]

  [ -f "$REPO_ROOT/tests/tmp/etc/xray/xray-reality-vision.json" ]
  [ -f "$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml" ]
  [ -f "$REPO_ROOT/tests/tmp/etc/xray/xray-xhttp.json" ]
  [ -f "$REPO_ROOT/tests/tmp/etc/caddy/Caddyfile" ]
  [ -f "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "repository does not contain committed generated secrets or complete node links" {
  run bash -c "cd '$REPO_ROOT' && grep -R --exclude-dir=.git --exclude-dir='tests/tmp' -E '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' ."
  [ "$status" -ne 0 ]

  run bash -c "cd '$REPO_ROOT' && grep -R --exclude-dir=.git --exclude-dir='tests/tmp' -E '(vless|hysteria2)://' ."
  [ "$status" -ne 0 ]
}

@test "install log redacts sensitive-looking values" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    scheme='vless'
    uuid_a='11111111'
    uuid_b='2222'
    uuid_c='3333'
    uuid_d='4444'
    uuid_e='555555555555'
    uuid=\"\${uuid_a}-\${uuid_b}-\${uuid_c}-\${uuid_d}-\${uuid_e}\"
    secret_a='AAAAAAAAAAAAAAAAAA'
    secret=\"\${secret_a}\${secret_a}\${secret_a}\"
    log \"privateKey=\${secret} password=\${secret} \${scheme}://example.invalid \${uuid}\"
    ! grep -q \"\${secret}\" \"\$INSTALL_LOG_FILE\"
    ! grep -q \"\${scheme}://\" \"\$INSTALL_LOG_FILE\"
    ! grep -q \"\${uuid}\" \"\$INSTALL_LOG_FILE\"
  "
  [ "$status" -eq 0 ]
}
