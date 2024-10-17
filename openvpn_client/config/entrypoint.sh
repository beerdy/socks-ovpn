#!/bin/sh

source /vpn/config/config

${SERVER=$OVPN_SERVER}

cp /vpn/config/config.ovpn.example /vpn/config/config.ovpn
sed -i "s/OVPN_PORT/$OVPN_PORT/g" /vpn/config/config.ovpn

# SSH tunneling
cp -r /root/.ssh/id_rsa.pub /vpn/config/
if [ "$TUNNEL_SERVER" = "127.0.0.1" ]; then
  sed -i "s/OVPN_SERVER/$TUNNEL_SERVER/g" /vpn/config/config.ovpn
  DEFAULT_GW=$(ip route show default | awk '/default/ {print $3}')
  ip route add $OVPN_SERVER/32 via $DEFAULT_GW dev eth0 metric 0
  ssh -p$TUNNEL_PORT -o StrictHostKeyChecking=no -L$OVPN_PORT:127.0.0.1:$OVPN_PORT $TUNNEL_USER@$OVPN_SERVER -N &
else
  sed -i "s/OVPN_SERVER/$OVPN_SERVER/g" /vpn/config/config.ovpn
fi

# Включение IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Настройка NAT
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables-save

# Запуск OpenVPN с предоставленной конфигурацией
exec openvpn --config /vpn/config/config.ovpn
