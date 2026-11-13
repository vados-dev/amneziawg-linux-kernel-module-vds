# Модуль ядра AmneziaWG (VDS)

[Русский](README.md) | [English](README_en.md)

Форк [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module).
Текущая версия VDS: `3.1.20260812-vds`.

## Содержание

- [Установка](#установка)
  - [Ubuntu](#ubuntu)
  - [Debian](#debian)
  - [Linux Mint](#linux-mint)
  - [RHEL/CentOS/SUSE/Fedora Core](#rhelcentossusefedora-core)
- [Ручная сборка](#ручная-сборка)
- [Настройка](#настройка)
- [Диагностика](#диагностика)
- [Лицензия](#лицензия)

## Установка

### Ubuntu

Откройте `Терминал` и выполните следующие шаги:

1. (Необязательно) Обновите систему до последних пакетов, включая доступную версию ядра: `apt-get full-upgrade`.
   После обновления ядра требуется перезагрузка.
2. Убедитесь, что для APT настроены репозитории с исходными кодами: откройте `vi /etc/apt/sources.list` и проверьте,
   что есть хотя бы одна раскомментированная строка, начинающаяся с `deb-src`.
3. Установите зависимости: `sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)`.
4. Выполните `sudo add-apt-repository ppa:amnezia/ppa`.
5. Установите пакет: `sudo apt-get install -y amneziawg`.

### Debian

Откройте `Терминал` и выполните следующие шаги:

1. (Необязательно) Обновите систему до последних пакетов, включая доступную версию ядра: `apt-get full-upgrade`.
   После обновления ядра требуется перезагрузка.
2. Убедитесь, что для APT настроены репозитории с исходными кодами: откройте `vi /etc/apt/sources.list` и проверьте,
   что есть хотя бы одна раскомментированная строка, начинающаяся с `deb-src`.
3. Выполните команды:
```shell
sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y amneziawg
```

### Linux Mint

Откройте `Источники приложений` и убедитесь, что включён пункт `Репозитории исходного кода`
(в разделе `Дополнительные источники`).

Перейдите в раздел `PPA`, добавьте репозиторий `ppa:amnezia/ppa`, сохраните настройки и обновите кэш `apt`.

После этого откройте `Терминал` и выполните:

```shell
sudo apt-get install -y amneziawg
```

### RHEL/CentOS/SUSE/Fedora Core

*Если в вашем дистрибутиве нет поддержки DKMS «из коробки», сначала может потребоваться установить
[EPEL](https://docs.fedoraproject.org/en-US/epel/#_quickstart).*

Откройте `Терминал` и выполните:

```shell
sudo dnf copr enable tigro/amneziawg
sudo dnf install amneziawg-dkms amneziawg-tools
```

Перед установкой настоятельно рекомендуется обновить ядро системы до последней доступной версии и перезагрузиться.

## Ручная сборка

Перед выполнением шагов может потребоваться установить заголовки ядра и пакеты для сборки.

1. В терминале:
    ```shell
    git clone https://github.com/vados-dev/amneziawg-linux-kernel-module-vds.git
    cd amneziawg-linux-kernel-module-vds/src
    ```

2. Если используется современное ядро Linux 5.6+, нужно скачать исходные коды ядра и связать полученное дерево
   с символической ссылкой `kernel`:

    ```shell
    ln -s /path/to/kernel/source kernel
    ```

   Нужно предоставить полное дерево исходных кодов ядра, а не только заголовки.
   **Для старого ядра (<5.6) этот шаг не нужен.**

3. Выполните сборку и установку:
    ```shell
    make
    sudo make install
    ```

   Либо, если система это позволяет, используйте DKMS:
    ```shell
    sudo make dkms-install
    ```

   и
    ```shell
    sudo dkms add -m amneziawg -v $(make print-version)
    sudo dkms build -m amneziawg -v $(make print-version)
    sudo dkms install -m amneziawg -v $(make print-version)
    ```
   или
    ```shell
    sudo dkms install "amneziawg/$(make print-version)"
    ```
   проверка:
    ```shell
    sudo modprobe amneziawg
    ```

## Настройка

> [!IMPORTANT]
> Все параметры должны совпадать на клиенте и сервере, кроме Jc, Jmin и Jmax — они могут различаться.

- Jc — 1 ≤ Jc ≤ 128; рекомендуемый диапазон — от 4 до 12 включительно
- Jmin — Jmax > Jmin < 1280*; рекомендуемое значение — 8
- Jmax — Jmin < Jmax ≤ 1280*; рекомендуемое значение — 80
- S1 — S1 ≤ 1132* (1280* - 148 = 1132); S1 + 56 ≠ S2; рекомендуемый диапазон — от 15 до 150 включительно
- S2 — S2 ≤ 1188* (1280* - 92 = 1188); рекомендуемый диапазон — от 15 до 150 включительно
- H1/H2/H3/H4 — должны быть уникальны между собой; рекомендуемый диапазон — от 5 до 2147483647 включительно

`* В предположении, что базовое интернет-соединение имеет MTU 1280.`

## Диагностика

> [!TIP]
> Дополнительные шаги диагностики см. в [документации Ubuntu Server](https://documentation.ubuntu.com/server/how-to/wireguard-vpn/troubleshooting).

### Включение отладочного логирования

Чтобы получить больше информации, включите динамическую отладку модуля:

```shell
echo "module amneziawg +p" | sudo tee /sys/kernel/debug/dynamic_debug/control
```

Сообщения будут попадать в dmesg; их можно смотреть в реальном времени:
```shell
dmesg -wT
```

### Мало места в `/tmp`

Большинство инструкций выше предполагают, что в разделе `/tmp` достаточно места: скрипт установки работает
с деревом исходных кодов ядра, которое занимает много места.

Если места в `/tmp` недостаточно, переопределите временный каталог переменной `AWG_TEMP_DIR` перед установкой:

```shell
export AWG_TEMP_DIR="/home/ubuntu/tmp"
```

Настройка сохранится для будущих запусков и не потребует повторения.

### Дерево исходных кодов ядра не найдено автоматически

В редких случаях скрипт установки не может автоматически найти дерево исходных кодов ядра. Найдите исходники
самостоятельно и свяжите их с исходниками DKMS-модуля, например:

```shell
ln -s /path/to/your/kernel/sources /usr/src/amneziawg-3.1.20260812-vds/kernel
```

После этого переустановите пакет — всё должно заработать.

При обновлении ядра в будущем может потребоваться обновить дерево исходных кодов и символические ссылки.

## Лицензия

Проект распространяется по лицензии [GPLv2](COPYING).
