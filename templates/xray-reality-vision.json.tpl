{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "reality-vision-in",
      "listen": "0.0.0.0",
      "port": {{REALITY_PORT}},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "{{REALITY_UUID}}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "{{REALITY_SERVER_NAME}}:443",
          "serverNames": [
            "{{REALITY_SERVER_NAME}}"
          ],
          "privateKey": "{{REALITY_PRIVATE_KEY}}",
          "shortIds": [
            "{{REALITY_SHORT_ID}}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ],
  "clientHints": {
    "fingerprint": "chrome",
    "publicKey": "{{REALITY_PUBLIC_KEY}}"
  }
}

