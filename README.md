socks5-ovpnc
=====================

Один контейнер: OpenVPN клиент + прокси (SOCKS5 и HTTP через gost).
Наружу публикуется только порт 1080.

Подготовка
-----
Скопируйте конфиг и отредактируйте:

    cp ./config/config.example ./config/config

Если требуется обойти блокировку VPN мобильных операторов, включите
SSH туннелирование, раскомментировав переменные в `./config/config` и добавьте
в OpenVPN сервер в `authorized_keys` сгенерированный ключ из `./config/id_rsa.pub`
(он появится после первого запуска контейнера).

Скопируйте ваши сертификаты:

    docker.crt
    docker.key
    ca.crt

в директорию `./config`.

Запуск
-----

    docker compose up --build -d

Настройка браузера
-----

    SOCKS v5
    localhost
    1080

Для Cursor/ChatGPT плагина (HTTP proxy):

    HTTP Proxy
    localhost
    8118

Опциональные переменные (можно задать в docker-compose.yml):
-----

    PROXY_USER
    PROXY_PASSWORD
    PROXY_PORT (по умолчанию 1080)
    HTTP_PROXY_PORT (по умолчанию 8118)

Используемое ПО
-----

- **gost** : [https://github.com/go-gost/gost](https://github.com/go-gost/gost)
- **OpenVPN Client** : [https://github.com/dperson/openvpn-client](https://github.com/dperson/openvpn-client)
