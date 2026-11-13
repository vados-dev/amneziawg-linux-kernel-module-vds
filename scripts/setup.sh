#!/usr/bin/env bash

set -uo pipefail

# Common vars
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
cur_dir="${SELF%/*}"

amf="/etc/modules-load.d/amneziawg.conf"
wmf="/etc/modules-load.d/wireguard.conf"
DTSTAMP="$(date +'%Y%m%d%H%M')"
mod_tmp_ver="3.1-${DTSTAMP}"
mod_repo_owner="vados-dev"
#mod_repo_owner="amnezia-vpn"
mod_repo="amneziawg-linux-kernel-module-vds"
#mod_repo="amneziawg-linux-kernel-module"
mod_branch="master"

setup_tmp="${cur_dir}/${mod_repo}-${mod_tmp_ver}"

# State
INST_DEPS=0
RM_DEPS=0
SETUP_MOD=0
ADD_AWG=0
CHK_AWG=0
ADD_WG=0
DEL_AWG=0
DEL_WG=0
REINSTALL=0
UNINSTALL=0
LOCAL_BUILD=0
ACTION=""
KERNEL_VERSION=""
MOD_BRANCH="${mod_branch}"

log()  { printf 'INFO: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

show_help() {
    cat << 'EOF'
Использование: sudo bash setup.sh [ОПЦИИ]

Скрипт для установки модуля ядра AmneziaWG на CentOS Stream 10.

Опции:
  -d, deps              Установить необходимые зависимости
  -rd, rmdeps           Удалить зависимости
  -s, setup             Установить модуль
  -aa, addawg           Добавить amneziawg в автозагрузку
  -ca, chkawg           Проверить и добавить amneziawg в автозагрузку
  -aw, addwg            Добавить wireguard в автозагрузку
  -da, delawg           Удалить amneziawg из автозагрузки
  -dw, delwg            Удалить wireguard из автозагрузки
  -r, reinstall         Переустановить модуль
  -u, uninstall         Удалить DKMS-регистрацию
  -k, --kernel VER      Собрать и установить модуль для указанной версии ядра
  -b, --branch BRANCH   Ветка VDS для клонирования (по умолчанию master)
  -l, --local           Собирать текущее дерево, не клонировать репозиторий
  -h, --help            Показать эту справку и выйти

Для подписи модуля и использования в Secure Boot:
Проверка, включён ли Secure Boot:
mokutil --sb-state
Импорт ключа:
mokutil --import /var/lib/dkms/mok.pub

EOF
}

install_deps() {
    dnf update -y || return 1
    dnf install -y dkms || return 1
    log "Зависимости установлены."
}

remove_deps() {
    dnf remove -y dkms || return 1
    log "Зависимости удалены."
}

add_awg_to_modules() {
    mkdir -p "$(dirname "$amf")" || return 1
    if ! grep -qxF 'amneziawg' "$amf" 2>/dev/null; then
        echo "amneziawg" > "$amf" || { warn "Write error $amf"; return 1; }
        log "Добавлено в $amf."
    fi
}

del_awg_from_modules() {
    rm -f "$amf" || { warn "Remove error $amf"; return 1; }
    log "$amf удалён."
}

add_wg_to_modules() {
    mkdir -p "$(dirname "$wmf")" || return 1
    if ! grep -qxF 'wireguard' "$wmf" 2>/dev/null; then
        echo "wireguard" > "$wmf" || { warn "Write error $wmf"; return 1; }
        log "Добавлено в $wmf."
    fi
}

del_wg_from_modules() {
    rm -f "$wmf" || { warn "Remove error $wmf"; return 1; }
    log "$wmf удалён."
}

update_kernel() {
    local ver="${KERNEL_VERSION:-}"
    local pkg_ver
    local arch
    arch="$(uname -m)"

    if [ -z "$ver" ]; then
        KERNEL_VERSION="$(uname -r)"
        log "Версия ядра не указана, используется текущая: $KERNEL_VERSION"
        return 0
    fi

    if [ "$ver" = "$(uname -r)" ] && [ -d "/lib/modules/${ver}/build" ]; then
        log "Ядро $ver уже работает, заголовки на месте."
        return 0
    fi

    pkg_ver="$ver"
    case "$pkg_ver" in
        *."$arch") pkg_ver="${pkg_ver%.*}" ;;
    esac

    log "Установка ядра $pkg_ver и заголовков."
    dnf install -y "kernel-${pkg_ver}" "kernel-devel-${pkg_ver}" "kernel-headers-${pkg_ver}" || {
        err "Не удалось установить ядро $pkg_ver."
        return 1
    }

    if [ ! -d "/lib/modules/${ver}/build" ]; then
        err "Заголовки для ядра $ver не найдены после установки."
        return 1
    fi

    log "Ядро $ver установлено; сборка будет выполнена для него."
}

start_setup() {
    local mod_ver
    local src_dir

    update_kernel || return $?

    if ! dnf list installed dkms >/dev/null 2>&1; then
        install_deps || return $?
    fi

    if [ "$LOCAL_BUILD" -eq 1 ]; then
        src_dir="$(pwd)/src"
        if [ ! -d "$src_dir" ]; then
            err "Каталог src не найден в $(pwd)."
            return 1
        fi
        log "Сборка локального дерева: $src_dir"
    else
        rm -rf "$setup_tmp"
        git clone --branch "$MOD_BRANCH" "https://github.com/${mod_repo_owner}/${mod_repo}.git" "$setup_tmp" || return 1
        src_dir="${setup_tmp}/src"
    fi

    mod_ver="$(make -C "$src_dir" print-version)" || return 1
    if [ -z "$mod_ver" ]; then
        err "Не удалось определить версию модуля."
        return 1
    fi

    make -C "$src_dir" dkms-install || return 1

    if [ -n "$KERNEL_VERSION" ]; then
        dkms install -m amneziawg -v "$mod_ver" -k "$KERNEL_VERSION" || return 1
    else
        dkms install -m amneziawg -v "$mod_ver" || return 1
    fi

    add_awg_to_modules || return 1
    log "Установлен amneziawg $mod_ver для ядра ${KERNEL_VERSION:-$(uname -r)}."
}

start_remove() {
    local ver

    ver="$(dkms status -m amneziawg 2>/dev/null | awk -F'[/, ]+' '{print $2}' | head -n1)"
    if [ -n "$ver" ]; then
        dkms remove "amneziawg/${ver}" --all || return 1
        log "Удалена регистрация DKMS amneziawg/${ver}."
    else
        warn "Регистрация DKMS amneziawg не найдена."
    fi

    del_awg_from_modules || return 1
    del_wg_from_modules || return 1
}

load_module() {
    local out
    if ! out="$(modprobe amneziawg 2>&1)"; then
        err "Модуль не загрузился: $out"
        return 1
    fi
    return 0
}

check_module() {
    if ! lsmod | grep -q -w amneziawg; then
        log "Модуль не загружен, загружаю."
        load_module || return 1
        log "Модуль загружен."
        add_awg_to_modules || return 1
    else
        log "Модуль amneziawg загружен."
    fi

    log "Информация о модуле:"
    modinfo amneziawg | grep -E "filename|version|vermagic|srcversion" || true
}

set_action() {
    if [ -n "$ACTION" ]; then
        err "Можно указать только одно действие."
        return 1
    fi
    ACTION="$1"
}

# Parse arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|deps)          set_action deps      || exit 1 ;;
        -rd|rmdeps)       set_action rmdeps    || exit 1 ;;
        -s|setup)         set_action setup     || exit 1 ;;
        -aa|addawg)       set_action addawg    || exit 1 ;;
        -ca|chkawg)       set_action chkawg    || exit 1 ;;
        -aw|addwg)        set_action addwg     || exit 1 ;;
        -da|delawg)       set_action delawg    || exit 1 ;;
        -dw|delwg)        set_action delwg     || exit 1 ;;
        -r|reinstall)     set_action reinstall || exit 1 ;;
        -u|uninstall)     set_action uninstall || exit 1 ;;
        -k|--kernel)
            shift
            [ "$#" -gt 0 ] || { err "Не указана версия ядра."; show_help; exit 1; }
            KERNEL_VERSION="$1"
            ;;
        -b|--branch)
            shift
            [ "$#" -gt 0 ] || { err "Не указана ветка."; show_help; exit 1; }
            MOD_BRANCH="$1"
            ;;
        -l|--local)       LOCAL_BUILD=1 ;;
        -h|--help)        show_help; exit 0 ;;
        *)                err "Неизвестный аргумент: $1"; show_help; exit 1 ;;
    esac
    shift
done

case "$ACTION" in
    "")        show_help; exit 0 ;;
    help)      show_help; exit 0 ;;
esac

[ "$(id -u)" -eq 0 ] || { err "Запускайте от root."; exit 1; }

case "$ACTION" in
    deps)      install_deps;      exit $? ;;
    rmdeps)    remove_deps;       exit $? ;;
    setup)     start_setup;       exit $? ;;
    addawg)    add_awg_to_modules; exit $? ;;
    chkawg)    check_module;      exit $? ;;
    addwg)     add_wg_to_modules; exit $? ;;
    delawg)    del_awg_from_modules; exit $? ;;
    delwg)     del_wg_from_modules;  exit $? ;;
    reinstall) start_remove || exit $?; start_setup; exit $? ;;
    uninstall) start_remove;      exit $? ;;
    *)         err "Неизвестное действие: $ACTION"; show_help; exit 1 ;;
esac
