#!/bin/bash

CURRENT_IP=$(nslookup openvpn_client | grep 'Address:' | tail -n 1 | awk '{ print $2 }')

ip route del default
ip route add default via $CURRENT_IP

/go/src/github.com/serjs/socks5/socks5
