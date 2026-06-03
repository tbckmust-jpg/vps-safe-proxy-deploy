#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com \
    bash "$REPO_ROOT/install.sh" all --dry-run --test-mode
  [ "$status" -eq 0 ]
}

@test "Reality Vision template renders required fields" {
  file="$REPO_ROOT/tests/tmp/etc/xray/xray-reality-vision.json"

  grep -q '"protocol": "vless"' "$file"
  grep -q '"network": "raw"' "$file"
  grep -q '"security": "reality"' "$file"
  grep -q '"flow": "xtls-rprx-vision"' "$file"
  grep -q '"fingerprint": "chrome"' "$file"
  grep -q '"decryption": "none"' "$file"
}

@test "Hysteria2 template renders required fields" {
  file="$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml"

  grep -q '^listen:' "$file"
  grep -q 'type: password' "$file"
  grep -q '^tls:' "$file"
  grep -q '^masquerade:' "$file"
  grep -q 'salamander' "$file"
}

@test "Hysteria2 uses ACME mode when domain and email are provided" {
  file="$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml"

  grep -q 'mode: "acme"' "$file"
  grep -q 'hy2.example.com' "$file"
}

@test "Hysteria2 falls back to self-signed mode without HY2_DOMAIN" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" hy2 --dry-run --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"self-signed TLS mode"* ]]
  grep -q 'mode: "self-signed"' "$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml"
}

@test "XHTTP template renders internal listener and random path" {
  file="$REPO_ROOT/tests/tmp/etc/xray/xray-xhttp.json"

  grep -q '"network": "xhttp"' "$file"
  grep -q '"listen": "127.0.0.1"' "$file"
  grep -Eq '"path": "/assets/[a-f0-9]+"' "$file"
}

@test "Caddyfile renders static site and random reverse proxy path" {
  file="$REPO_ROOT/tests/tmp/etc/caddy/Caddyfile"

  grep -q 'file_server' "$file"
  grep -Eq 'handle /assets/[a-f0-9]+\*' "$file"
  grep -q 'reverse_proxy 127.0.0.1:' "$file"
}
