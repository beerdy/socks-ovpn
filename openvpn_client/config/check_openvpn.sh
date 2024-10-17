#!/bin/bash

# Проверяем, запущен ли OpenVPN
if pgrep openvpn >/dev/null; then
  echo "OpenVPN is running"
  exit 0
else
  echo "OpenVPN is not running"
  exit 1
fi
