#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"
}

@test "verify-exports passes for generated no-domain all exports without printing links" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" all --test-mode
  [ "$status" -eq 0 ]

  run env -i PATH="$PATH" \
    bash "$REPO_ROOT/install.sh" verify-exports --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS credentials file exists"* ]]
  [[ "$output" == *"PASS credentials permission is 600"* ]]
  [[ "$output" == *"PASS [reality-vision] appears once"* ]]
  [[ "$output" == *"PASS [hysteria2] appears once"* ]]
  [[ "$output" == *"PASS [xhttp-cdn] appears once"* ]]
  [[ "$output" == *"PASS Reality v2rayN link exists"* ]]
  [[ "$output" == *"PASS Reality sing-box outbound exists"* ]]
  [[ "$output" == *"PASS HY2 native URI exists"* ]]
  [[ "$output" == *"PASS HY2 v2rayN_xray_uri exists"* ]]
  [[ "$output" == *"PASS HY2 client yaml exists"* ]]
  [[ "$output" == *"PASS HY2 sing-box outbound exists"* ]]
  [[ "$output" == *"PASS HY2 secret URL-safe"* ]]
  [[ "$output" == *"PASS HY2 self-signed insecure exists"* ]]
  [[ "$output" == *"PASS XHTTP v2rayN link exists"* ]]
  [[ "$output" == *"PASS XHTTP no-domain security=none"* ]]
  [[ "$output" == *"PASS XHTTP sing-box tls.enabled=false"* ]]
  [[ "$output" == *"PASS no duplicate sections"* ]]
  [[ "$output" == *"PASS no complete proxy URI printed to terminal"* ]]
  [[ "$output" != *"://"* ]]
}

@test "verify-exports fails clearly when credentials are missing" {
  run env -i PATH="$PATH" \
    bash "$REPO_ROOT/install.sh" verify-exports --test-mode
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL credentials file exists"* ]]
  [[ "$output" != *"://"* ]]
}

@test "verify-exports detects duplicate sections without printing values" {
  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" all --test-mode
  [ "$status" -eq 0 ]

  printf '%s\n' '[hysteria2]' >>"$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"

  run env -i PATH="$PATH" \
    bash "$REPO_ROOT/install.sh" verify-exports --test-mode
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL [hysteria2] appears once"* ]]
  [[ "$output" == *"FAIL no duplicate sections"* ]]
  [[ "$output" != *"://"* ]]
}
