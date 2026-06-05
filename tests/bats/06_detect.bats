#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

run_candidate_detect() {
  local fixture="$1"
  local manager="$2"
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/${fixture}" \
    DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM DETECT_ARCH=x86_64 \
    DETECT_PACKAGE_MANAGER="$manager" DETECT_BBR_AVAILABLE=true \
    DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free DETECT_UDP_8443_STATUS="no local listener; external mapping unknown" \
    bash "$REPO_ROOT/install.sh" detect --test-mode
}

assert_full_candidate() {
  local manager="$1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Package manager: ${manager}"* ]]
  [[ "$output" == *"Service manager: systemd"* ]]
  [[ "$output" == *"Support level: full install candidate"* ]]
  [[ "$output" == *"Reality Vision: full install candidate"* ]]
  [[ "$output" == *"Hysteria2: full install candidate with UDP warning"* ]]
  [[ "$output" == *"XHTTP + Caddy: full install candidate"* ]]
  [[ "$output" == *"BBR: supported"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect reports Debian 13 apt systemd root as full install candidate" {
  run_candidate_detect os-release-debian13 apt
  [[ "$output" == *"OS: Debian GNU/Linux 13 (trixie)"* ]]
  assert_full_candidate apt
}

@test "detect reports Ubuntu 24.04 apt systemd root as full install candidate" {
  run_candidate_detect os-release-ubuntu2404 apt
  [[ "$output" == *"OS: Ubuntu 24.04 LTS"* ]]
  assert_full_candidate apt
}

@test "detect reports Fedora dnf systemd root as full install candidate" {
  run_candidate_detect os-release-fedora dnf
  [[ "$output" == *"OS family: redhat"* ]]
  assert_full_candidate dnf
}

@test "detect reports Rocky dnf systemd root as full install candidate" {
  run_candidate_detect os-release-rocky dnf
  [[ "$output" == *"OS: Rocky Linux 9.4"* ]]
  assert_full_candidate dnf
}

@test "detect reports AlmaLinux dnf systemd root as full install candidate" {
  run_candidate_detect os-release-alma dnf
  [[ "$output" == *"OS: AlmaLinux 9.4"* ]]
  assert_full_candidate dnf
}

@test "detect reports CentOS yum systemd root as full install candidate" {
  run_candidate_detect os-release-centos yum
  [[ "$output" == *"OS: CentOS Stream 9"* ]]
  assert_full_candidate yum
}

@test "detect reports Arch pacman systemd root as full install candidate" {
  run_candidate_detect os-release-arch pacman
  [[ "$output" == *"OS family: arch"* ]]
  assert_full_candidate pacman
}

@test "detect reports openSUSE zypper systemd root as full install candidate" {
  run_candidate_detect os-release-opensuse zypper
  [[ "$output" == *"OS family: suse"* ]]
  assert_full_candidate zypper
}

@test "detect reports Alpine OpenRC as dry-run only" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-alpine" \
    DETECT_INIT_SYSTEM=openrc DETECT_IS_ROOT=true DETECT_VIRT=LXC DETECT_ARCH=x86_64 DETECT_PACKAGE_MANAGER=unknown DETECT_BBR_AVAILABLE=true \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"OS: Alpine Linux v3.23"* ]]
  [[ "$output" == *"Init system: openrc"* ]]
  [[ "$output" == *"Support level: dry-run only"* ]]
  [[ "$output" == *"Reality Vision: dry-run only"* ]]
  [[ "$output" == *"Hysteria2: dry-run only"* ]]
  [[ "$output" == *"XHTTP + Caddy: dry-run only"* ]]
  [[ "$output" == *"BBR: kernel supports bbr; applying may be unavailable in container"* ]]
  [[ "$output" == *"BBR: kernel supports bbr; apply permission unknown in container"* ]]
  [[ "$output" != *"BBR: supported"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect infers LXC from cgroup fixture and avoids simple BBR supported" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-alpine" \
    DETECT_SKIP_SYSTEMD_DETECT_VIRT=true DETECT_PROC_1_CGROUP_FILE="$REPO_ROOT/tests/fixtures/cgroup-lxc" \
    DETECT_PROC_SELF_CGROUP_FILE="$REPO_ROOT/tests/fixtures/cgroup-lxc" DETECT_DOCKERENV_FILE="$REPO_ROOT/tests/fixtures/missing-dockerenv" \
    DETECT_PROC_1_ENVIRON_FILE="$REPO_ROOT/tests/fixtures/missing-environ" DETECT_PROC_SELF_STATUS_FILE="$REPO_ROOT/tests/fixtures/missing-status" \
    DETECT_INIT_SYSTEM=openrc DETECT_IS_ROOT=true DETECT_ARCH=x86_64 DETECT_PACKAGE_MANAGER=unknown DETECT_BBR_AVAILABLE=true \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"Virtualization: LXC"* ]]
  [[ "$output" == *"BBR: kernel supports bbr; applying may be unavailable in container"* ]]
  [[ "$output" != *"BBR: supported"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect treats missing unzip as installable when apt is present" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian13" \
    DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM DETECT_ARCH=x86_64 DETECT_PACKAGE_MANAGER=apt \
    DETECT_MISSING_COMMANDS="unzip" DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"Support level: full install candidate"* ]]
  [[ "$output" == *"unzip: missing; installable via apt"* ]]
  [[ "$output" == *"Reality Vision: full install candidate"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect marks NAT TCP-only as HY2 candidate with UDP warning" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian13" \
    NAT_MODE=true HY2_UDP_MAPPED=false DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM DETECT_ARCH=x86_64 DETECT_PACKAGE_MANAGER=apt \
    DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAT_MODE: true"* ]]
  [[ "$output" == *"Reality Vision: full install candidate"* ]]
  [[ "$output" == *"Hysteria2: full install candidate with UDP warning"* ]]
  [[ "$output" == *"XHTTP + Caddy: full install candidate"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}

@test "detect respects INSTALL_HY2 false without generating credentials" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian13" \
    INSTALL_HY2=false DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM DETECT_ARCH=x86_64 DETECT_PACKAGE_MANAGER=apt \
    DETECT_TCP_443_STATUS=free DETECT_TCP_2053_STATUS=free \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hysteria2: skipped because INSTALL_HY2=false"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
  if [ -f "$REPO_ROOT/tests/tmp/mock-calls.log" ]; then
    ! grep -q 'systemctl restart' "$REPO_ROOT/tests/tmp/mock-calls.log"
  fi
}

@test "detect reports unknown package manager as unsupported with clear reason" {
  run env -i PATH="$PATH" OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release-debian13" \
    DETECT_INIT_SYSTEM=systemd DETECT_IS_ROOT=true DETECT_VIRT=KVM DETECT_ARCH=x86_64 DETECT_PACKAGE_MANAGER=unknown \
    bash "$REPO_ROOT/install.sh" detect --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"Support level: unsupported"* ]]
  [[ "$output" == *"Support reason: unsupported or missing package manager"* ]]
  [[ "$output" == *"Reality Vision: unsupported"* ]]
  [ ! -e "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt" ]
}
