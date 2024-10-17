socks5-ovpnc
=====================

Настройка OpenVPN клиента
-----
Скопируйте config:

    cp ./openvpn_client/config.example ./openvpn_client/config

Если требуется обойти блокировку VPN мобильных операторов включите
SSH туннелирование, раскоментировав одноименные переменные и добавьте
в OpenVPN сервер в `authorized_keys` сгенерированные ключ из `id_rsa.pub`

Скопируйте ваши:

    docker.crt
    docker.key
    ca.crt

В директорию `openvpn_client/config`

Настройка браузера
-----

    SOCKS v5
    localhost
    1080

Используемое ПО
-----

- **SOCKS 5 Server** : [https://github.com/serjs/socks5-server](https://github.com/serjs/socks5-server)
- **OpenVPN Client** : [https://github.com/dperson/openvpn-client](https://github.com/dperson/openvpn-client)
