#!/bin/bash

CONFIG_FILE=$(find "$(dirname "$0")" -maxdepth 1 -name "*.ovpn" | head -n 1)

if [ -z "$CONFIG_FILE" ]; then
  echo "No .ovpn file found."
  exit 1
fi

if pgrep -f "openvpn --config $CONFIG_FILE" > /dev/null; then
  echo "OpenVPN is already running."
else
  sudo openvpn --config "$CONFIG_FILE" --daemon
  echo "OpenVPN started."
fi
