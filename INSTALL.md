# Установка и обновление VDS

[Русский](INSTALL.md) | [English](INSTALL_en.md)

Текущая версия VDS: `3.1.20260812-vds`.

## Требования

- Заголовки ядра для работающего ядра.
- DKMS.
- Инструменты сборки: `make`, `gcc`, `git`.

## Fedora/RHEL/CentOS

Установите заголовки ядра и пересоберите модуль:

```shell
sudo dnf install -y kernel-devel-$(uname -r)
sudo dkms install "amneziawg/$(dkms status | grep amneziawg | awk -F'[/, ]+' '{print $2}' | head -1)" -k $(uname -r)
```

Чтобы не повторять это в будущем, установите метапакет с заголовками ядра.

## Обновление до новой версии

```shell
cd amneziawg-linux-kernel-module-vds/src
git pull

# Удалить старую регистрацию DKMS:
sudo dkms remove "amneziawg/$(dkms status | grep amneziawg | awk -F'[/, ]+' '{print $2}' | head -1)" --all

# Установить новую версию:
sudo make dkms-install
sudo dkms install "amneziawg/$(make print-version)"
```

## Проверка

```shell
modinfo amneziawg | grep -E 'filename|version'
sudo modprobe amneziawg
```
