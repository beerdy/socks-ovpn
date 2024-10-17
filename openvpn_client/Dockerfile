FROM alpine:3.7

# Install runtime dependencies. The versions are pinned for reproducible,
# deterministic, pure builds.
RUN apk --update add curl openvpn iproute2 iptables openssh

# Создание устройства TUN/TAP
RUN mkdir -p /dev/net && mknod /dev/net/tun c 10 200 && chmod 600 /dev/net/tun

# Для SSH
RUN ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N ""

# Log the public ip address of the container in every minute.
HEALTHCHECK --interval=60s --timeout=15s --start-period=120s \
  CMD curl 'https://api.ipify.org'

# This is where the configuration files will go.
VOLUME [ "/vpn/config" ]

ENTRYPOINT [ "/vpn/config/entrypoint.sh" ]
