{{CADDY_SITE_ADDRESS}} {
  {{CADDY_TLS_LINE}}
  root * {{CADDY_SITE_DIR}}

  # Only this random asset path is proxied to local Xray XHTTP.
  handle {{XHTTP_PATH}}* {
    reverse_proxy {{XHTTP_INTERNAL_HOST}}:{{XHTTP_INTERNAL_PORT}}
  }

  # All other paths behave like a normal static HTTPS website.
  handle {
    try_files {path} /index.html
    file_server
  }
}
