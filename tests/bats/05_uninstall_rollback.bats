#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

debug_failure_context() {
  local scheme_re='(vless|hysteria2)'
  {
    echo "# status=$status"
    echo "# output:"
    printf '%s\n' "$output" \
      | sed -E "s#${scheme_re}://[^[:space:]]*#<redacted-node-link>#g" \
      | sed -E 's#[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}#<redacted-uuid>#g'
    if [ -f "$REPO_ROOT/tests/tmp/mock-calls.log" ]; then
      echo "# mock calls:"
      cat "$REPO_ROOT/tests/tmp/mock-calls.log"
    fi
    echo "# generated files:"
    find "$REPO_ROOT/tests/tmp" -maxdepth 4 -type f ! -name credentials.txt -print | sort
    if [ -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]; then
      echo "# credentials file:"
      ls -l "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
    fi
  } >&3
}

@test "xray test failure restores previous config" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    mkdir -p \"\$ETC_DIR/xray\"
    printf old >\"\$XRAY_CONFIG_FILE\"
    printf SENSITIVE_CONFIG_MARKER >\"\$ETC_DIR/xray/rendered.json\"
    export MOCK_XRAY_TEST_FAIL=1
    stage_xray_config_with_rollback \"\$ETC_DIR/xray/rendered.json\" \"\$XRAY_CONFIG_FILE\" xray
  "
  [ "$status" -ne 0 ]
  grep -q '^old$' "$REPO_ROOT/tests/tmp/etc/xray/config.json"
  [ -d "$REPO_ROOT/tests/tmp/backups" ]
  grep -q 'xray run -test -confdir' "$REPO_ROOT/tests/tmp/mock-calls.log"
  [[ "$output" == *"attempted xray config test forms"* ]]
  [[ "$output" != *"SENSITIVE_CONFIG_MARKER"* ]]
}

@test "xray config test failure stops before credentials are generated" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 MOCK_XRAY_TEST_FAIL=1 \
    bash "$REPO_ROOT/install.sh" reality --test-mode
  [ "$status" -ne 0 ]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
  [ ! -e "$REPO_ROOT/tests/tmp/etc/xray/xray-reality-vision.json" ]
  grep -q 'xray run -test -confdir' "$REPO_ROOT/tests/tmp/mock-calls.log"
  [[ "$output" == *"xray config test failed; restoring previous config"* ]]
}

@test "systemctl restart failure restores previous config" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
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
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
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
    xray run -test -confdir '$REPO_ROOT/tests/tmp/xray'
    xray run -test -config '$REPO_ROOT/tests/tmp/example.json'
    hysteria server --config '$REPO_ROOT/tests/tmp/hy2.yaml'
    caddy validate --config '$REPO_ROOT/tests/tmp/Caddyfile'
    ufw allow 443/tcp
  "
  [ "$status" -eq 0 ]
  grep -q 'systemctl restart xray' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'xray run -test -confdir' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'xray run -test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'hysteria server --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'caddy validate --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'ufw allow 443/tcp' "$REPO_ROOT/tests/tmp/mock-calls.log"

  run bash -c "PATH='$REPO_ROOT/tests/mocks':\"\$PATH\" MOCK_CADDY_FAIL=1 caddy validate"
  [ "$status" -ne 0 ]
}

@test "xray config test supports run test config form" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    mkdir -p \"\$TEST_TMP_DIR/standalone\"
    printf '{}' >\"\$TEST_TMP_DIR/standalone/config.json\"
    export MOCK_XRAY_LEGACY_TEST_UNSUPPORTED=1
    xray_test_config \"\$TEST_TMP_DIR/standalone/config.json\"
  "
  [ "$status" -eq 0 ]
  grep -q 'xray run -test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  ! grep -q 'xray test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
}

@test "xray config test falls back to short config form" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    mkdir -p \"\$TEST_TMP_DIR/standalone\"
    printf '{}' >\"\$TEST_TMP_DIR/standalone/config.json\"
    export MOCK_XRAY_RUN_CONFIG_FAIL=1
    xray_test_config \"\$TEST_TMP_DIR/standalone/config.json\"
  "
  [ "$status" -eq 0 ]
  grep -q 'xray run -test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'xray run -test -c' "$REPO_ROOT/tests/tmp/mock-calls.log"
}

@test "new xray without legacy test subcommand passes through run test confdir" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 MOCK_XRAY_LEGACY_TEST_UNSUPPORTED=1 \
    bash "$REPO_ROOT/install.sh" reality --test-mode
  [ "$status" -eq 0 ]
  grep -q 'xray run -test -confdir' "$REPO_ROOT/tests/tmp/mock-calls.log"
  ! grep -q 'xray test -config' "$REPO_ROOT/tests/tmp/mock-calls.log"
}

@test "systemd ExecStart and xray config test use same confdir" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    xray_systemd_unit_content >\"\$TEST_TMP_DIR/xray.service\"
    printf new >\"\$ETC_DIR/xray/rendered.json\"
    stage_xray_config_with_rollback \"\$ETC_DIR/xray/rendered.json\" \"\$XRAY_REALITY_CONFIG_FILE\" xray
    grep -q \"ExecStart=.* -confdir \$ETC_DIR/xray\" \"\$TEST_TMP_DIR/xray.service\"
    grep -q \"xray run -test -confdir \$ETC_DIR/xray\" \"\$TEST_TMP_DIR/mock-calls.log\"
  "
  [ "$status" -eq 0 ]
}

@test "xray x25519 PublicKey output parses without printing keys" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    PATH=\"\$PROJECT_ROOT/tests/mocks:\$PATH\"
    export PATH TEST_MODE DRY_RUN TEST_TMP_DIR
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    MOCK_XRAY_X25519_FORMAT=publickey generate_reality_keypair
    [[ \"\$REALITY_PRIVATE_KEY\" == MOCK_PRIVATE_KEY ]]
    [[ \"\$REALITY_PUBLIC_KEY\" == MOCK_PUBLIC_KEY ]]
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"MOCK_PRIVATE_KEY"* ]]
  [[ "$output" != *"MOCK_PUBLIC_KEY"* ]]
}

@test "xray x25519 Password PublicKey output parses without printing keys" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    PATH=\"\$PROJECT_ROOT/tests/mocks:\$PATH\"
    export PATH TEST_MODE DRY_RUN TEST_TMP_DIR
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    MOCK_XRAY_X25519_FORMAT=password generate_reality_keypair
    [[ \"\$REALITY_PRIVATE_KEY\" == MOCK_PRIVATE_KEY ]]
    [[ \"\$REALITY_PUBLIC_KEY\" == MOCK_PUBLIC_KEY ]]
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"MOCK_PRIVATE_KEY"* ]]
  [[ "$output" != *"MOCK_PUBLIC_KEY"* ]]
}

@test "xray x25519 parse failure reports labels without leaking keys" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    PATH=\"\$PROJECT_ROOT/tests/mocks:\$PATH\"
    export PATH TEST_MODE DRY_RUN TEST_TMP_DIR
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/xray_install.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    MOCK_XRAY_X25519_FORMAT=broken generate_reality_keypair
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"xray x25519 output labels: PrivateKey, Hash32"* ]]
  [[ "$output" != *"SHOULD_NOT_LEAK_PRIVATE"* ]]
  [[ "$output" != *"MOCK_PRIVATE_KEY"* ]]
  [[ "$output" != *"MOCK_PUBLIC_KEY"* ]]
}

@test "Reality keygen failure rolls back project-created xray unit" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 MOCK_XRAY_X25519_FORMAT=broken MOCK_XRAY_INSTALL_WRITES_UNIT=1 \
    bash "$REPO_ROOT/install.sh" reality --test-mode
  [ "$status" -ne 0 ]
  [ ! -e "$REPO_ROOT/tests/tmp/etc/systemd/system/xray.service" ]
  grep -q 'systemctl stop xray' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl disable --now xray' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl daemon-reload' "$REPO_ROOT/tests/tmp/mock-calls.log"
  [[ "$output" == *"failed to generate Reality x25519 keypair with xray"* ]]
  [[ "$output" != *"SHOULD_NOT_LEAK_PRIVATE"* ]]
  [[ "$output" != *"MOCK_PRIVATE_KEY"* ]]
  [[ "$output" != *"MOCK_PUBLIC_KEY"* ]]
}

@test "test-mode all invokes real install path through mocks" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com \
    bash "$REPO_ROOT/install.sh" all --test-mode
  if [ "$status" -ne 0 ]; then
    debug_failure_context
  fi
  [ "$status" -eq 0 ]

  grep -q 'xray x25519' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'xray run -test -confdir' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'hysteria version' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'caddy version' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'caddy validate --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl restart xray' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl restart hysteria-server' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl restart caddy' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'ufw allow 443/tcp' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'ufw allow 8443/udp' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'ufw allow 2053/tcp' "$REPO_ROOT/tests/tmp/mock-calls.log"
  [[ "$output" == *"Install summary"* ]]
  [[ "$output" == *"Reality: installed"* ]]
  [[ "$output" == *"Hysteria2: installed"* ]]
  [[ "$output" == *"XHTTP+Caddy: installed"* ]]
  [[ "$output" == *"credentials path:"* ]]
}

@test "all continues to XHTTP when HY2 fails after Reality succeeds" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com \
    MOCK_SYSTEMCTL_FAIL_SERVICE=hysteria-server bash "$REPO_ROOT/install.sh" all --test-mode
  [ "$status" -ne 0 ]
  grep -q 'xray x25519' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl restart hysteria-server' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'caddy version' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'caddy validate --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
  grep -q 'systemctl restart caddy' "$REPO_ROOT/tests/tmp/mock-calls.log"
  [[ "$output" == *"Reality: installed"* ]]
  [[ "$output" == *"Hysteria2: failed"* ]]
  [[ "$output" == *"XHTTP+Caddy: installed"* ]]
  [[ "$output" != *"://"* ]]
}

@test "caddy validate failure restores previous Caddyfile" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    TEST_MODE=true
    DRY_RUN=false
    TEST_TMP_DIR=\"\$PROJECT_ROOT/tests/tmp\"
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/platform.sh\"
    . \"\$PROJECT_ROOT/lib/service_manager.sh\"
    . \"\$PROJECT_ROOT/lib/caddy_site.sh\"
    init_runtime \"\$PROJECT_ROOT\"
    apply_default_config
    configure_runtime_paths
    prepare_runtime_dirs
    printf old >\"\$CADDY_CONFIG_FILE\"
    printf new >\"\$CADDY_RENDERED_CONFIG_FILE\"
    MOCK_CADDY_VALIDATE_FAIL=1 stage_caddy_config_with_rollback \"\$CADDY_RENDERED_CONFIG_FILE\"
  "
  [ "$status" -ne 0 ]
  grep -q '^old$' "$REPO_ROOT/tests/tmp/etc/caddy/Caddyfile"
  grep -q 'caddy validate --config' "$REPO_ROOT/tests/tmp/mock-calls.log"
}

@test "BBR unsupported does not interrupt all in test mode" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com MOCK_BBR_UNSUPPORTED=1 \
    bash "$REPO_ROOT/install.sh" all --test-mode
  if [ "$status" -ne 0 ]; then
    debug_failure_context
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"kernel does not report BBR support; skipping"* ]]
}

@test "firewall command missing does not interrupt install" {
  run bash -c "
    set -euo pipefail
    PROJECT_ROOT='$REPO_ROOT'
    DRY_RUN=false
    TEST_MODE=false
    ENABLE_FIREWALL=true
    PATH='/usr/bin:/bin'
    . \"\$PROJECT_ROOT/lib/common.sh\"
    . \"\$PROJECT_ROOT/lib/firewall.sh\"
    allow_firewall_port 443 tcp
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ufw not found"* ]]
}

@test "status does not leak full node links" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" status --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" != *"://"* ]]
  [[ "$output" == *"credentials file:"* ]]
}
