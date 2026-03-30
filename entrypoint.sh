#!/bin/sh
set -eu

# Точка входа контейнера
# Поднимает SSH-туннель, OpenVPN и gost

CONFIG_DIR=/vpn/config
SETTINGS_PATH=${CONFIG_DIR}/config
OPENVPN_TEMPLATE_PATH=${CONFIG_DIR}/config.ovpn.example
OPENVPN_CONFIG_PATH=${CONFIG_DIR}/config.ovpn
ROOT_SSH_DIR=/root/.ssh
OPENVPN_PID_PATH=/run/openvpn.pid

# Проверяет файл настроек
#
# @return [void]
require_settings_file() {
  if [ ! -f "$SETTINGS_PATH" ]; then
    echo "Не найден файл настроек ${SETTINGS_PATH} Скопируйте config.example в config и заполните параметры" >&2
    exit 1
  fi
}

# Загружает настройки
#
# @return [void]
load_settings() {
  . "$SETTINGS_PATH"
}

# Проверяет обязательные параметры OpenVPN
#
# @return [void]
validate_settings() {
  if [ -z "${OVPN_PORT:-}" ] || [ -z "${OVPN_SERVER:-}" ]; then
    echo "В ${SETTINGS_PATH} должны быть заданы OVPN_PORT и OVPN_SERVER" >&2
    exit 1
  fi
}

# Проверяет нужен ли локальный SSH-туннель
#
# @return [Boolean]
uses_local_tunnel() {
  [ "${TUNNEL_SERVER:-}" = "127.0.0.1" ]
}

# Подготавливает SSH-ключи
# Если ключей нет, создает их
#
# @return [void]
prepare_ssh_keys() {
  mkdir -p "$ROOT_SSH_DIR" "$CONFIG_DIR"

  if [ ! -f "${CONFIG_DIR}/id_rsa" ] || [ ! -f "${CONFIG_DIR}/id_rsa.pub" ]; then
    ssh-keygen -t rsa -b 2048 -f "${CONFIG_DIR}/id_rsa" -q -N ""
  fi

  cp "${CONFIG_DIR}/id_rsa" "${ROOT_SSH_DIR}/id_rsa"
  cp "${CONFIG_DIR}/id_rsa.pub" "${ROOT_SSH_DIR}/id_rsa.pub"
  chmod 600 "${ROOT_SSH_DIR}/id_rsa"
  chmod 644 "${ROOT_SSH_DIR}/id_rsa.pub"
}

# Собирает OpenVPN-конфиг из шаблона
# Для SSH-туннеля подставляет локальный адрес
#
# @return [void]
render_openvpn_config() {
  remote_host="$OVPN_SERVER"

  if uses_local_tunnel; then
    remote_host="$TUNNEL_SERVER"
  fi

  cp "$OPENVPN_TEMPLATE_PATH" "$OPENVPN_CONFIG_PATH"
  sed -i "s/OVPN_SERVER/${remote_host}/g" "$OPENVPN_CONFIG_PATH"
  sed -i "s/OVPN_PORT/${OVPN_PORT}/g" "$OPENVPN_CONFIG_PATH"
}

# Добавляет отдельный маршрут до транспортного хоста через eth0
# Это не дает трафику SSH-проброса уйти внутрь VPN
#
# @return [void]
route_transport_host() {
  default_gateway=$(ip route show default | awk '/default/ {print $3}')
  ip route replace "${OVPN_SERVER}/32" via "$default_gateway" dev eth0 metric 0
}

# Ждет пока локальный порт начнет принимать соединения
#
# @param port [String] локальный порт OpenVPN
# @param timeout_seconds [String] таймаут в секундах
# @return [void]
wait_for_local_port() {
  port="$1"
  timeout_seconds="$2"
  counter=0

  while [ "$counter" -lt "$timeout_seconds" ]; do
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
    counter=$((counter + 1))
  done

  echo "Истекло время ожидания локального порта 127.0.0.1:${port}" >&2
  exit 1
}

# Запускает SSH local-forward до OpenVPN-сервера
#
# @return [void]
start_ssh_tunnel() {
  if [ -z "${TUNNEL_USER:-}" ] || [ -z "${TUNNEL_PORT:-}" ]; then
    echo "Для SSH-туннеля в ${SETTINGS_PATH} должны быть заданы TUNNEL_USER и TUNNEL_PORT" >&2
    exit 1
  fi

  ssh-keyscan -p "$TUNNEL_PORT" "$OVPN_SERVER" >> "${ROOT_SSH_DIR}/known_hosts" 2>/dev/null || true

  ssh \
    -p "$TUNNEL_PORT" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=3 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=10 \
    -L "${OVPN_PORT}:127.0.0.1:${OVPN_PORT}" \
    "${TUNNEL_USER}@${OVPN_SERVER}" -N &

  wait_for_local_port "$OVPN_PORT" 30
}

# Запускает OpenVPN в фоне
#
# @return [void]
start_openvpn() {
  openvpn --config "$OPENVPN_CONFIG_PATH" --daemon --writepid "$OPENVPN_PID_PATH"
}

# Ждет появления интерфейса tun0
#
# @return [void]
wait_for_tun0() {
  counter=0

  while [ "$counter" -lt 60 ]; do
    if ip link show tun0 >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
    counter=$((counter + 1))
  done

  echo "Интерфейс tun0 не появился Вероятно OpenVPN не смог подключиться" >&2
  exit 1
}

# Запускает gost
# Поддерживает SOCKS5 и HTTP с опциональной авторизацией
#
# @return [void]
start_gost() {
  socks_port="${PROXY_PORT:-1080}"
  http_port="${HTTP_PROXY_PORT:-8118}"
  socks_listener="socks5://0.0.0.0:${socks_port}"
  http_listener="http://0.0.0.0:${http_port}"

  if [ -n "${PROXY_USER:-}" ] && [ -n "${PROXY_PASSWORD:-}" ]; then
    socks_listener="socks5://${PROXY_USER}:${PROXY_PASSWORD}@0.0.0.0:${socks_port}"
    http_listener="http://${PROXY_USER}:${PROXY_PASSWORD}@0.0.0.0:${http_port}"
  fi

  exec /usr/local/bin/gost -L "$socks_listener" -L "$http_listener"
}

# Проверяет и загружает настройки
require_settings_file
load_settings
validate_settings

# Подготавливает ключи и итоговый OpenVPN-конфиг
prepare_ssh_keys
render_openvpn_config

# Поднимает SSH-туннель и отдельный маршрут до транспортного хоста
if uses_local_tunnel; then
  route_transport_host
  start_ssh_tunnel
fi

# Поднимает OpenVPN и после этого запускает прокси
start_openvpn
wait_for_tun0
start_gost
