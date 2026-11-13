#!/usr/bin/env bash

#set -uo pipefail
set -e -o pipefail
shopt -s extglob
export LC_ALL=C

# Common vars
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "${SELF}")"
export PATH="${SELF_DIR}:$PATH"
ME_SELF="${SELF##*/}"
ME_CLEAN="${ME_SELF%.*}"
PROGRAM="${0##*/:-$ME_CLEAN}"
ARGS=( "$@" )
echo $ME_CLEAN
exit 0
PARENT_DIR="$(dirname "${SELF_DIR}")"
repo_root="$(cd "${PARENT_DIR}" && pwd)"

amf="/etc/modules-load.d/amneziawg.conf"
wmf="/etc/modules-load.d/wireguard.conf"
DTSTAMP="$(date +'%Y%m%d%H%M')"
mod_tmp_ver="3.1-${DTSTAMP}"
mod_repo_owner="vados-dev"
#mod_repo_owner="amnezia-vpn"
mod_repo="amneziawg-linux-kernel-module-vds"
#mod_repo="amneziawg-linux-kernel-module"
mod_branch="master"

setup_tmp="${ME_CLEAN}/${mod_repo}-${mod_tmp_ver}"

# State
ACTION=""
KERNEL_VERSION=""
MOD_BRANCH="${mod_branch}"
LOCAL_BUILD=0
NONINTERACTIVE=0

# Common functions
cmd()  { printf '  [\033[1;33m✨\033[0m]\033[1m %s \033[0m\n' "$*" >&2; "$@"; }
log()  { printf ' \033[1;34m 📋 INFO:\033[0;8m [%s] - %s.\033[0m\n' "$PROGRAM" "$*"; }
warn() { printf ' \033[1;33m ⚡ WARN:\033[0;1m [%s] - %s.\033[0m\n' "$PROGRAM" "$*" >&2; }
err()  { printf ' \033[0;31m ⚫ ERROR:\033[0;1m [%s] - %s!\033[0m\n' "$PROGRAM" "$*" >&2; }
die()  { printf ' \033[1;31m ❌ CRITICAL:\033[0;1m [%s] - %s!\033[0m\n' "$PROGRAM" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root!"

confirm() { local answer; read -r -p "$(cecho sW "    $1 [y/N]: ")" answer; [[ "$answer" =~ ^[Yy]$ ]] || return 1; }

#-> version_ge A B -> 0, если версия A >= B. Сравнение почленное
version_ge() {
    local a="$1" b="$2"
    [[ "$a" == "$b" ]] && return 0
    local -a pa pb; IFS='.' read -ra pa <<<"$a"; IFS='.' read -ra pb <<<"$b"
    local i
    for ((i = 0; i < ${#pb[@]}; i++)); do
        local x="${pa[i]:-0}" y="${pb[i]:-0}"
        ((10#${x:-0} > 10#${y:-0})) && return 0
        ((10#${x:-0} < 10#${y:-0})) && return 1
    done
    return 0
}

check_os() { [[ -r /etc/os-release ]] && source "/etc/os-release"; os_id="$ID"; os_ver="$VERSION_ID" || { echo "Нет /etc/os-release!"; exit 1; }; }
validate_os_ver() {
    check_os
    case "$os_id" in
        "ubuntu") version_ge "$os_ver" "22.04" && os_type="deb"  || die "Ubuntu ${os_ver}: проверялось на 24.04+!" ;;
        "debian") version_ge "$os_ver" "12"    && os_type="deb"  || die "Debian ${os_ver}: проверялось на 12+!" ;;
        "almalinux") version_ge "$os_ver" "9"  && os_type="rhel" || die "Almalinux ${os_ver}: проверялось на 9+!" ;;
        "rocky") version_ge "$os_ver" "9"      && os_type="rhel" || die "Rocky ${os_ver}: проверялось на 9+!" ;;
        "centos") version_ge "$os_ver" "9"     && os_type="rhel" || die "CentOS ${os_ver}: проверялось на 9+!" ;;
        *) die "ОС '${os_ver}' не проверялась; ожидается Ubuntu 24.04+ / Debian 12+ / Almalinux 9+ / Rocky 9+ / Centos 9+." ;;
    esac #    print_ok "ОС: ${os_id} ${os_ver}, Тип ОС: ${os_type}"
}


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
  -k, --kernel VER      Собрать и установить модуль для указанной версии ядра;
                        пустое значение означает обновление до последнего ядра
  -b, --branch BRANCH   Ветка VDS для клонирования (по умолчанию master)
  -l, --local           Собирать текущее дерево, не клонировать репозиторий
  -y, --yes             Неинтерактивный режим (для CI): без подтверждений
  -h, --help            Показать эту справку и выйти

Для подписи модуля и использования в Secure Boot:
Проверка, включён ли Secure Boot:
mokutil --sb-state
Импорт ключа:
mokutil --import /var/lib/dkms/mok.pub

EOF
}

confirm() {
    local prompt="$1"

    if [ "$NONINTERACTIVE" -eq 1 ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        warn "Нет терминала для подтверждения, продолжаю."
        return 0
    fi

    local answer
    read -r -p "${prompt} [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

check_os() {
    local os_id
    local os_ver

    if [ ! -r /etc/os-release ]; then
        err "Не найден /etc/os-release."
        return 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-}"
    os_ver="${VERSION_ID:-}"

    case "$os_id" in
        centos|almalinux|rocky|rhel) ;;
        *)
            err "ОС '${os_id:-unknown}' не поддерживается; ожидается RHEL-семейство 9+."
            return 1
            ;;
    esac

    case "${os_ver%%.*}" in
        9|10) ;;
        *)
            err "Версия ОС '${os_ver:-unknown}' не поддерживается; ожидается 9 или 10."
            return 1
            ;;
    esac

    log "ОС: ${os_id} ${os_ver}."
}

CHECK_PKGS="amneziawg-tools amneziawg-dkms mc git make curl wget libmnl-dev pkg-config fail2ban firewalld firewalld-filesystem nftables python3 python3-pip pythov-venv qrencode)
# kernel-headers-$(uname -r) kernel-devel-$(uname -r) 


check_dnf_updates() { dnf check-update -y > /dev/null 2>&1 || true; }

install_dnf_repos() {
    dnf config-manager --enable crb || true
    dnf install -y epel-release || true
    dnf config-manager --enable epel-release || true
    dnf copr enable -y tigro/amneziawg centos-stream-${os_ver}-$(arch)
    dnf clean all || true
    dnf makecache || true
}

#-> Функция проверки зависимостей от vados-dev в стиле dnf:
check_deps() {
    local packages=("$@")
    local to_install=()
    local deps_pkg
    log "Список: ${packages[*]}"
    for deps_pkg in "${packages[@]}"; do
        if ! dnf list installed "$deps_pkg" 2>/dev/null | grep -q "Installed Packages"; then
             to_install+=("$deps_pkg")
        fi
    done
        if [ ${#to_install[@]} -eq 0 ]; then
            log "Все зависимости установлены."; return 0
        else
            log "Установка: ${to_install[*]}..."
            dnf install -y ${to_install[*]} > /dev/null 2>&1 && log "Зависимости установлены." || die "Ошибка установки зависимостей!"
        fi
}

install_deps() {
    if [[ "$os_type" == "rhel" ]]; then
        local deps=()
        deps="${CHECK_PKGS}"
    local pkgs=(dkms gcc make git tar gzip which curl)

    log "Установка зависимостей: ${pkgs[*]}"
    if dnf install -y "${pkgs[@]}"; then
        log "Зависимости установлены."
        return 0
    fi

    # dkms в EL10 поставляется только из EPEL: в чистом образе репозиторий
    # не подключён, поэтому повторяем установку после включения EPEL и CRB.
    warn "Не удалось установить зависимости, включаю EPEL и CRB и повторяю."
    dnf install -y dnf-plugins-core epel-release || true
    dnf config-manager --set-enabled crb || true
    dnf makecache || true
    dnf install -y "${pkgs[@]}" || {
        err "Не удалось установить зависимости."
        return 1
    }
    log "Зависимости установлены."
}

remove_deps() {
    dnf remove -y dkms || {
        err "Не удалось удалить dkms."
        return 1
    }
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

latest_installed_kernel() {
    rpm -q --last kernel 2>/dev/null \
        | awk '/^kernel-/{print $1; exit}' \
        | sed 's/^kernel-//'
}

update_kernel() {
    local ver="${KERNEL_VERSION:-}"
    local pkg_ver
    local arch

    arch="$(uname -m)"

    if [ -z "$ver" ]; then
        log "Версия ядра не указана: обновление до последней доступной."
        confirm "Обновить ядро и заголовки до последней версии?" || {
            err "Обновление ядра отменено."
            return 1
        }
        dnf install -y kernel kernel-devel kernel-headers || {
            err "Не удалось установить последнее ядро."
            return 1
        }
        ver="$(latest_installed_kernel)"
        if [ -z "$ver" ]; then
            err "Не удалось определить установленную версию ядра."
            return 1
        fi
        log "Установлено ядро: $ver"
    elif [ -d "/lib/modules/${ver}/build" ]; then
        log "Заголовки для ядра $ver уже установлены."
    else
        pkg_ver="$ver"
        case "$pkg_ver" in
            *."$arch") pkg_ver="${pkg_ver%.*}" ;;
        esac

        log "Установка ядра $pkg_ver и заголовков."
        dnf install -y "kernel-${pkg_ver}" "kernel-devel-${pkg_ver}" kernel-headers || {
            err "Не удалось установить ядро $pkg_ver."
            return 1
        }
    fi

    if [ ! -d "/lib/modules/${ver}/build" ]; then
        err "Заголовки для ядра $ver не найдены после установки."
        return 1
    fi

    KERNEL_VERSION="$ver"
    log "Целевое ядро для сборки: $KERNEL_VERSION."
}

start_setup() {
    local mod_ver
    local src_dir

    check_os || return 1
    update_kernel || return $?

    if ! command -v make >/dev/null 2>&1 \
        || ! command -v gcc >/dev/null 2>&1 \
        || ! dnf list installed dkms >/dev/null 2>&1; then
        install_deps || return $?
    fi

    if [ "$LOCAL_BUILD" -eq 1 ]; then
        src_dir="${repo_root}/src"
        if [ ! -d "$src_dir" ]; then
            err "Каталог src не найден в ${repo_root}."
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

    confirm "Удалить регистрацию DKMS amneziawg?" || return 1

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
        -y|--yes)         NONINTERACTIVE=1 ;;
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
    deps)      check_os || exit $?; install_deps;  exit $? ;;
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
