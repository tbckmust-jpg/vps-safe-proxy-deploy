#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

@test "Reality export uses external port in NAT mode" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 NAT_MODE=true REALITY_EXTERNAL_PORT=15443 \
    bash "$REPO_ROOT/install.sh" reality --dry-run --test-mode
  [ "$status" -eq 0 ]
  grep -q ':15443?' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "Hysteria2 export uses external UDP port in NAT mode" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 NAT_MODE=true HY2_EXTERNAL_PORT=18443 \
    bash "$REPO_ROOT/install.sh" hy2 --dry-run --test-mode
  [ "$status" -eq 0 ]
  grep -q ':18443/' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "XHTTP export uses external HTTPS port in NAT mode" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 XHTTP_DOMAIN=cdn.example.com NAT_MODE=true XHTTP_EXTERNAL_PORT=12053 \
    bash "$REPO_ROOT/install.sh" xhttp --dry-run --test-mode
  [ "$status" -eq 0 ]
  grep -q ':12053?' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

