FROM alpine:3.19
RUN apk --no-cache add openvpn iproute2 iptables openssh curl tzdata
RUN mkdir -p /dev/net /run && mknod /dev/net/tun c 10 200 && chmod 600 /dev/net/tun
ARG GOST_VERSION="3.2.6"
ARG TARGETARCH
RUN set -e; \
  case "$TARGETARCH" in \
    amd64) GOST_ARCH="linux_amd64"; GOST_SHA="b39037b0380ea001fb3c0c28441c2e10bfc694f90682739a65b53e55dce5238b" ;; \
    arm64) GOST_ARCH="linux_arm64"; GOST_SHA="f674c8f4a033dc1dfd4f0d5e9602fbe5b0d0f81307bf3794f44b5b5d6d622eae" ;; \
    *) echo "Unsupported TARGETARCH=$TARGETARCH"; exit 1 ;; \
  esac; \
  curl -fsSL -o /tmp/gost.tar.gz "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_${GOST_ARCH}.tar.gz"; \
  echo "${GOST_SHA}  /tmp/gost.tar.gz" | sha256sum -c -; \
  tar -xzf /tmp/gost.tar.gz -C /usr/local/bin gost; \
  rm -f /tmp/gost.tar.gz
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
VOLUME [ "/vpn/config" ]
ENTRYPOINT [ "/entrypoint.sh" ]
