#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

@test "xray test failure restores previous config" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    mkdir -p \"\$ETC_DIR/xray\"
    printf old >\"\$XRAY_CONFIG_FILE\"
    printf new >\"\$ETC_DIR/xray/rendered.json\"
    MOCK_XRAY_TEST_FAIL=1 stage_xray_config_with_rollback \"\$ETC_DIR/xray/rendered.json\" \"\$XRAY_CONFIG_FILE\" xray
  "
  [ "$status" -ne 0 ]
  grep -q '^old$' "$REPO_ROOT/tests/tmp/etc/xray/config.json"
  [ -d "$REPO_ROOT/tests/tmp/backups" ]
  grep -q 'xray test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
}

@test "systemctl restart failure restores previous config" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    mkdir -p \"\$ETC_DIR/xray\"
    printf old >\"\$XRAY_CONFIG_FILE\"
    printf new >\"\$ETC_DIR/xray/rendered.json\"
    MOCK_SYSTEMCTL_FAIL=1 stage_xray_config_with_rollback \"\$ETC_DIR/xray/rendered.json\" \"\$XRAY_CONFIG_FILE\" xray
  "
  [ "$status" -ne 0 ]
  grep -q '^old$' "$REPO_ROOT/tests/tmp/etc/xray/config.json"
  grep -q 'systemctl restart xray' "$REPO_ROOT/tests/tmp/mock-calls.log"
}

@test "uninstall preserves credentials unless purge is explicit" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -eq 0 ]
  [ -f "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]

  run env -i PATH="$PATH" bash "$REPO_ROOT/install.sh" uninstall --dry-run --test-mode
  [ "$status" -eq 0 ]
  [ -f "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "uninstall purge removes credentials only when not dry-run" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    PURGE=true
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/uninstall.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    secure_credentials_file
    printf secret >\"\$CREDENTIALS_FILE\"
    uninstall_all
    [ ! -e \"\$CREDENTIALS_FILE\" ]
  "
  [ "$status" -eq 0 ]
}

@test "all mocks record calls and expose failure controls" {
  run bash -c "
    set -euo pipefail
    PATH='$REPO_ROOT/tests/mocks':\"\$PATH\"
    rm -f '$REPO_ROOT/tests/tmp/mock-calls.log'
    systemctl restart xray
    xray test -config '$REPO_ROOT/tests/tmp/example.json'
    hysteria server --config '$REPO_ROOT/tests/tmp/hy2.yaml'
    caddy validate --config '$REPO_ROOT/tests/tmp/Caddyfile'
    ufw allow 443/tcp
  "
  [ "$status" -eq 0 ]
  grep -q 'systemctl restart xray' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'xray test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'hysteria server --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'caddy validate --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'ufw allow 443/tcp' "$REPO_ROOT/tests/tmp/mock-calls.log"

  run bash -c "PATH='$REPO_ROOT/tests/mocks':\"\$PATH\" MOCK_CADDY_FAIL=1 caddy validate"
  [ "$status" -ne 0 ]
}
