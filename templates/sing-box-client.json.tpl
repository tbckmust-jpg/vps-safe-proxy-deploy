{
  "outbounds": [
    {
      "type": "vless",
      "tag": "reality-vision",
      "server": "{{PUBLIC_HOST}}",
      "server_port": {{REALITY_PORT}},
      "uuid": "{{REALITY_UUID}}",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "{{REALITY_SERVER_NAME}}",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "{{REALITY_PUBLIC_KEY}}",
          "short_id": "{{REALITY_SHORT_ID}}"
        }
      }
    },
    {
      "type": "vless",
      "tag": "xhttp-cdn",
      "server": "{{PUBLIC_HOST}}",
      "server_port": {{XHTTP_HTTPS_PORT}},
      "uuid": "{{XHTTP_UUID}}",
      "tls": {
        "enabled": true,
        "server_name": "{{XHTTP_DOMAIN}}"
      },
      "transport": {
        "type": "xhttp",
        "path": "{{XHTTP_PATH}}",
        "headers": {
          "Host": "{{XHTTP_DOMAIN}}"
        }
      }
    }
  ]
}

