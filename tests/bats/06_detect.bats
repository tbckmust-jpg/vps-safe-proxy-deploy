#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

@test "detect reports Alpine OpenRC as dry-run only" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-alpine" \
    DETECT_INIT_SYSTEM=OpenRC DETECT_IS_ROOT=true DETECT_VIRT=LXC \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"OS: Alpine Linux v3.23"* ]]
  [[ "$output" == *"Init system: OpenRC"* ]]
  [[ "$output" == *"Virtualization: LXC"* ]]
  [[ "$output" == *"Reality Vision: dry-run only"* ]]
  [[ "$output" == *"Hysteria2: dry-run only"* ]]
  [[ "$output" == *"XHTTP + Caddy: dry-run only"* ]]
  [[ "$output" == *"BBR: unsupported in container"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect reports Debian systemd as full install supported" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian" \
    DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM DETECT_BBR_STATUS=supported \
    DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free DETECT_UDP_8443_STATUS="no local listener; external mapping unknown" \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"OS: Debian GNU/Linux 12 (bookworm)"* ]]
  [[ "$output" == *"Init system: systemd"* ]]
  [[ "$output" == *"Root: yes"* ]]
  [[ "$output" == *"Systemd supported: yes"* ]]
  [[ "$output" == *"PUBLIC_HOST: 203.0.113.10 (auto-detected)"* ]]
  [[ "$output" == *"Reality Vision: full install supported"* ]]
  [[ "$output" == *"Hysteria2: full install supported"* ]]
  [[ "$output" == *"XHTTP + Caddy: full install supported"* ]]
  [[ "$output" == *"BBR: supported"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect marks NAT TCP-only as HY2 unavailable" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian" \
    NAT_MODE=true HY2_UDP_MAPPED=false DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM \
    DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAT_MODE: true"* ]]
  [[ "$output" == *"Reality Vision: full install supported"* ]]
  [[ "$output" == *"Hysteria2: unavailable because UDP is not mapped / unknown"* ]]
  [[ "$output" == *"XHTTP + Caddy: full install supported"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect respects INSTALL_HY2 false without generating credentials" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian" \
    INSTALL_HY2=false DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM \
    DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hysteria2: skipped because INSTALL_HY2=false"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
  if [ -f "$REPO_ROOT/tests/tmp/mock-calls.log" ]; then
    ! grep -q 'systemctl restart' "$REPO_ROOT/tests/tmp/mock-calls.log"
  fi
}
