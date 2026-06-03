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
    XHTTP_INTERNAL_HOST XHTTP_INTERNAL_PORT MASQUERADE_MODE MASQUERADE_PROXY_URL \
    ROOT_DIR ETC_DIR LOG_DIR CREDENTIALS_FILE XRAY_CONFIG_FILE HY2_CONFIG_FILE CADDY_CONFIG_FILE BACKUP_DIR \
    ENABLE_BBR ENABLE_FIREWALL XRAY_VERSION HY2_VERSION BIN_DIR SYSTEMD_DIR SYSCTL_BBR_FILE; do
    grep -q "^${name}=" "$REPO_ROOT/config.env.example"
  done
}

@test "missing PUBLIC_HOST gives a clear error" {
  run env -i PATH="$PATH" bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -ne 0 ]
  [[ "$output" == *"PUBLIC_HOST is required"* ]]
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
