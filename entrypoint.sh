#!/bin/sh
set -e

if [ ! -f /vpn/config/config ]; then
  echo "Missing /vpn/config/config (copy config.example to config and edit)" >&2
  exit 1
fi

. /vpn/config/config

if [ -z "$OVPN_PORT" ] || [ -z "$OVPN_SERVER" ]; then
  echo "OVPN_PORT and OVPN_SERVER must be set in /vpn/config/config" >&2
  exit 1
fi

mkdir -p /root/.ssh /vpn/config
if [ ! -f /vpn/config/id_rsa ] || [ ! -f /vpn/config/id_rsa.pub ]; then
  ssh-keygen -t rsa -b 2048 -f /vpn/config/id_rsa -q -N ""
fi
cp /vpn/config/id_rsa /root/.ssh/id_rsa
cp /vpn/config/id_rsa.pub /root/.ssh/id_rsa.pub

cp /vpn/config/config.ovpn.example /vpn/config/config.ovpn
sed -i "s/OVPN_PORT/${OVPN_PORT}/g" /vpn/config/config.ovpn

# SSH tunneling
if [ -n "$TUNNEL_SERVER" ] && [ "$TUNNEL_SERVER" = "127.0.0.1" ]; then
  sed -i "s/OVPN_SERVER/${TUNNEL_SERVER}/g" /vpn/config/config.ovpn
  DEFAULT_GW=$(ip route show default | awk '/default/ {print $3}')
  ip route replace ${OVPN_SERVER}/32 via ${DEFAULT_GW} dev eth0 metric 0
  if [ -n "$TUNNEL_USER" ] && [ -n "$TUNNEL_PORT" ]; then
    ssh-keyscan -p "$TUNNEL_PORT" "$OVPN_SERVER" >> /root/.ssh/known_hosts 2>/dev/null || true
    ssh -p"$TUNNEL_PORT" -o StrictHostKeyChecking=no -L"$OVPN_PORT:127.0.0.1:$OVPN_PORT" "$TUNNEL_USER@$OVPN_SERVER" -N &
  else
    echo "TUNNEL_USER and TUNNEL_PORT must be set for SSH tunneling" >&2
    exit 1
  fi
else
  sed -i "s/OVPN_SERVER/${OVPN_SERVER}/g" /vpn/config/config.ovpn
fi

# Start OpenVPN in background
openvpn --config /vpn/config/config.ovpn --daemon --writepid /run/openvpn.pid

# Wait for tun0 to appear before starting SOCKS5
for i in $(seq 1 60); do
  if ip link show tun0 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! ip link show tun0 >/dev/null 2>&1; then
  echo "tun0 did not appear; OpenVPN likely failed to connect" >&2
  exit 1
fi

SOCKS_PORT="${PROXY_PORT:-1080}"
HTTP_PORT="${HTTP_PROXY_PORT:-8118}"

SOCKS_LISTEN="socks5://0.0.0.0:${SOCKS_PORT}"
HTTP_LISTEN="http://0.0.0.0:${HTTP_PORT}"
if [ -n "${PROXY_USER}" ] && [ -n "${PROXY_PASSWORD}" ]; then
  SOCKS_LISTEN="socks5://${PROXY_USER}:${PROXY_PASSWORD}@0.0.0.0:${SOCKS_PORT}"
  HTTP_LISTEN="http://${PROXY_USER}:${PROXY_PASSWORD}@0.0.0.0:${HTTP_PORT}"
fi

exec /usr/local/bin/gost -L "${SOCKS_LISTEN}" -L "${HTTP_LISTEN}"
