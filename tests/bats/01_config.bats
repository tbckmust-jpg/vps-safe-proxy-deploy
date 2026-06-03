#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

@test "config example contains required variables" {
  for name in \
    PUBLIC_HOST EMAIL HY2_DOMAIN XHTTP_DOMAIN REALITY_SERVER_NAME \
    REALITY_PORT HY2_PORT XHTTP_HTTPS_PORT \
    NAT_MODE REALITY_EXTERNAL_PORT HY2_EXTERNAL_PORT XHTTP_EXTERNAL_PORT \
    INSTALL_REALITY INSTALL_HY2 INSTALL_XHTTP HY2_UDP_MAPPED \
    XHTTP_INTERNAL_HOST XHTTP_INTERNAL_PORT MASQUERADE_MODE MASQUERADE_PROXY_URL \
    ROOT_DIR ETC_DIR LOG_DIR CREDENTIALS_FILE XRAY_CONFIG_FILE HY2_CONFIG_FILE CADDY_CONFIG_FILE BACKUP_DIR \
    ENABLE_BBR ENABLE_FIREWALL XRAY_VERSION HY2_VERSION BIN_DIR SYSTEMD_DIR SYSCTL_BBR_FILE; do
    grep -q "^${name}=" "$REPO_ROOT/config.env.example"
  done
}

@test "missing PUBLIC_HOST auto-detects when possible" {
  run env -i PATH="$PATH" bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto-detected PUBLIC_HOST=203.0.113.10"* ]]
  grep -q ':443?' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "PUBLIC_HOST auto-detect failure gives a clear error" {
  run bash -c "env -i PATH=\"$PATH\" MOCK_PUBLIC_HOST_FAIL=1 bash \"$REPO_ROOT/install.sh\" reality --dry-run --test-mode 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed to auto-detect PUBLIC_HOST"* ]]
  [[ "$output" == *"PUBLIC_HOST is required"* ]]
  [[ "$output" == *"PUBLIC_HOST=1.2.3.4"* ]]
}

@test "default ports are assigned to the expected schemes" {
  grep -q '^REALITY_PORT=443$' "$REPO_ROOT/config.env.example"
  grep -q '^HY2_PORT=8443$' "$REPO_ROOT/config.env.example"
  grep -q '^XHTTP_HTTPS_PORT=2053$' "$REPO_ROOT/config.env.example"
}

@test "NAT_MODE true exports the external port" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 NAT_MODE=true REALITY_EXTERNAL_PORT=15443 \
    bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -eq 0 ]
  grep -q ':15443?' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "NAT_MODE false exports the listen port" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 NAT_MODE=false REALITY_EXTERNAL_PORT=15443 \
    bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -eq 0 ]
  grep -q ':443?' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "dry-run refuses redirected paths outside tests tmp" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 ROOT_DIR=/root \
    bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -ne 0 ]
  [[ "$output" == *"must stay under"* ]]
}

@test "Alpine real install exits before requiring PUBLIC_HOST" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-alpine" \
    bash "$REPO_ROOT/install.sh" all
  [ "$status" -ne 0 ]
  [[ "$output" == *"Alpine/OpenRC is not supported for real installation"* ]]
  [[ "$output" != *"PUBLIC_HOST is required"* ]]
}

@test "Alpine dry-run can continue and render configs" {
  run env -i PATH="$REPO_ROOT/tests/mocks:$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-alpine" \
    bash "$REPO_ROOT/install.sh" all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto-detected PUBLIC_HOST=203.0.113.10"* ]]
  [ -f "$REPO_ROOT/tests/tmp/etc/xray/xray-reality-vision.json" ]
}

@test "INSTALL_HY2 false skips HY2 in all mode" {
  run env -i PATH="$PATH" INSTALL_HY2=false bash "$REPO_ROOT/install.sh" all --dry-run --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"HY2 skipped because INSTALL_HY2=false"* ]]
  grep -q 'Hysteria2: skipped by INSTALL_HY2=false' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  scheme="hysteria2"
  ! grep -q "${scheme}://" "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  [ ! -e "$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml" ]
}
