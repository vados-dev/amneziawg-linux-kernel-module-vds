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

# State
ACTION=""
KERNEL="$(uname -r)"
KERNEL_VERSION="$(uname -r)"
MOD_BRANCH="${mod_branch}"
LOCAL_BUILD=0
NONINTERACTIVE=0

# Common functions
cmd()  { printf '  [\033[1;33m✨\033[0m]\033[1m %s \033[0m\n' "$*" >&2; "$@"; }
log()  { printf ' \033[1;34m 📋 INFO:\033[0;8m [%s] - %s.\033[0m\n' "$PROGRAM" "$*"; }
warn() { printf ' \033[1;33m ⚡ WARN:\033[0;1m [%s] - %s.\033[0m\n' "$PROGRAM" "$*" >&2; }
err()  { printf ' \033[0;31m ⚫ ERROR:\033[0;1m [%s] - %s!\033[0m\n' "$PROGRAM" "$*" >&2; }
die()  { printf ' \033[1;31m ❌ CRITICAL:\033[0;1m [%s] - %s!\033[0m\n' "$PROGRAM" "$*" >&2; exit 1; }

check_root() { [ "$(id -u)" -eq 0 ] || die "Запускайте от root."; }
check_os() {
    # shellcheck disable=SC1091
    [[ -r /etc/os-release ]] && source "/etc/os-release"; os_id="$ID"; os_ver="$VERSION_ID" || die "Нет /etc/os-release!"
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
    case "$os_id" in
        "ubuntu") version_ge "$os_ver" "22.04" && os_type="deb"  || die "Ubuntu ${os_ver}: проверялось на 24.04+!" ;;
        "debian") version_ge "$os_ver" "12"    && os_type="deb"  || die "Debian ${os_ver}: проверялось на 12+!" ;;
        "almalinux") version_ge "$os_ver" "9"  && os_type="rhel" || die "Almalinux ${os_ver}: проверялось на 9+!" ;;
        "rocky") version_ge "$os_ver" "9"      && os_type="rhel" || die "Rocky ${os_ver}: проверялось на 9+!" ;;
        "centos") version_ge "$os_ver" "9"     && os_type="rhel" || die "CentOS ${os_ver}: проверялось на 9+!" ;;
        *) die "ОС '${os_ver}' не проверялась; ожидается Ubuntu 24.04+ / Debian 12+ / Almalinux 9+ / Rocky 9+ / Centos 9+." ;;
    esac
    log "ОС: ${os_id} ${os_ver}, Тип ОС: ${os_type}"
    if [[ "$os_type" == "rhel" ]]; then
        SRC_DIR="/usr/src"
        BASE_PKGS="amneziawg-dkms gcc make git tar gzip which curl libmnl-dev pkg-config"
        #setup_tmp="${SELF_DIR}/${mod_repo}-${mod_tmp_ver}"
    else
        SRC_DIR="${SRC_DIR:-/usr/local/src}"
        BASE_PKGS="dkms make curl ca-certificates iproute2 iptables python3 python3-venv python3-pip golang-go"
    fi
}

check_dnf_updates() { ! dnf check-update -y > /dev/null 2>&1 && err "dnf обновления не проверены!" || log "dnf обновления проверены."; }
install_dnf_repos() {
    log "Проверка dnf обновлений..."
    check_dnf_updates > /dev/null 2>&1 || warn "check_dnf_updates не завершилась корректно: $?"
    log "Настройка dnf репозиториев..."
    dnf -y install dnf-plugins-core || err "Ошибка установки dnf-plugins-core!"
    do_enable() { out=$(dnf config-manager --enable $1) > /dev/null 2>&1 || err "$1 не включилась ${out}!"; }
    is_enabled() { dnf -q repoinfo "$1" 2>/dev/null | grep -qi 'status[[:space:]]*:[[:space:]]*enabled'; }
    is_copr() { dnf -q repolist --enabled | grep -qi "copr.*$1"; }
    is_enabled crb > /dev/null 2>&1 || do_enable crb
    is_enabled epel > /dev/null 2>&1 || { dnf install -y epel-release; do_enable epel; }
    is_copr "tigro/amneziawg" > /dev/null 2>&1 || { dnf copr enable -y tigro/amneziawg centos-stream-${os_ver}-$(arch); } 
    ret=$(dnf clean all && dnf makecache) > /dev/null 2>&1 || err "Ошибка 'dnf clean all && dnf makecache': ${ret}"
    log "Насмтройка dnf репозиториев закончена."
}

check_deps() {
    local packages=("$@")
    local to_install=()
    local deps_pkg
    log "Список: ${packages[*]}"
    for deps_pkg in "${packages[@]}"; do
        if ! dnf list installed "$deps_pkg" > /dev/null 2>&1 | grep -q "Installed Packages"; then
             to_install+=("$deps_pkg")
        fi
    done
        if [ ${#to_install[@]} -eq 0 ]; then
            log "Все зависимости установлены."
        else
            log "Установка: ${to_install[*]}..."
            dnf install -y ${to_install[*]} > /dev/null 2>&1 && log "Зависимости установлены." || die "Ошибка установки зависимостей!"
        fi
}

install_deps() {
    local pkgs=("$@")
    log "Проверка и установка зависимостей"
    if [[ "$os_type" == "rhel" ]]; then
        install_dnf_repos > /dev/null 2>&1 || die "Ошибка настройки dnf репозиториев!"
        log "Установка зависимостей: ${pkgs[*]}"
        check_deps "${pkgs[@]}" > /dev/null 2>&1 && log "Зависимости установлены" || die "Зависимости не установлены!"
    else
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq; apt-get install -y -qq --no-install-recommends ${pkgs[*]};
        log "Базовые пакеты (включая golang-go из репозитория) установлены."
    fi
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

start_setup() {
    local mod_ver src_dir
    if [[ "$os_type" == "rhel" ]]; then
        if ! command -v make >/dev/null 2>&1 || ! command -v gcc >/dev/null 2>&1 \
        || ! dnf list installed "amneziawg-dkms" 2>/dev/null | grep -q "Installed Packages"; then
            install_deps "$BASE_PKGS"
        fi

        if [ "$LOCAL_BUILD" -eq 1 ]; then
            src_dir="${repo_root}/src"
            [ -d "$src_dir" ] || die "Каталог src не найден в ${repo_root}."
            log "Сборка локального дерева: $src_dir"
        else
            rm -rf "$setup_tmp"
            git clone --branch "$MOD_BRANCH" "https://github.com/${mod_repo_owner}/${mod_repo}.git" "$setup_tmp" || return 1
            src_dir="${setup_tmp}/src"
        fi
        
        cd ${src_dir}
        ! make print-version > /dev/null 2>&1 && mod_ver="$(cat version.h | grep "define WIREGUARD_VERSION" | awk -F'[/" ]+' '{print $3}')" \
        || mod_ver="$(make print-version)"
    
        sudo make dkms-install && \
        sudo dkms install -m amneziawg -v ${mod_ver}
        add_awg_to_modules
        log "Установлен amneziawg $mod_ver."
    else
        warn "Здесь код для deb"
    fi
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

show_help() {
    cat << 'EOF'
Использование: sudo bash setup.sh [ОПЦИИ]

Скрипт для установки модуля ядра AmneziaWG на OS:
Almalinux 9+ / Rocky 9+ / Centos 9+ Stream / Ubuntu 24.04+ / Debian 12+.

Опции:
  -d, deps              Установить необходимые зависимости и выйти
  -rd, rmdeps           Удалить зависимости и выйти
  -s, setup             Установить зависимости, модуль,
                        Проверить и добавить amneziawg в автозагрузку 
  -aa, addawg           Добавить amneziawg в автозагрузку
  -ca, chkawg           Проверить и добавить amneziawg в автозагрузку
  -aw, addwg            Добавить wireguard в автозагрузку
  -da, delawg           Удалить amneziawg из автозагрузки
  -dw, delwg            Удалить wireguard из автозагрузки
  -r, reinstall         Переустановить модуль
  -u, uninstall         Удалить DKMS-регистрацию
#-> Это нужно делать в образе, из merge.yml, с его перезагрузкой
#  -k, --kernel VER      Собрать и установить модуль для указанной версии ядра
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

### Старт работы скрипта
########################
#-> Проверки:
check_root
check_os

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
#        -k|--kernel)
#            shift
#            [ "$#" -gt 0 ] || { err "Не указана версия ядра."; show_help; exit 1; }
#            KERNEL_VERSION="$1"
#            ;;
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

case "$ACTION" in
    deps)      install_deps "$BASE_PKGS";  exit $? ;;
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

# Образец работы с аргументами:
#-> Flags и Обработка аргументов вверху почему-то
### Flags:
##########
#ENABLE=""; DISABLE=""; ENABLE_NOW=""; DISABLE_NOW=""; START=""; STOP=""; RESTART=""; STATUS=""; HELP=0;

### Обработка аргументов
########################
#NO_ARGS=0
#COMMAND=""
#HELP_EXIT_RC=0 # C1: 0 = явный help (exit 0); ставится в 1 для ошибок использования
#ARGS=""
#let $# || { NO_ARGS=1; HELP=1; }
#while [[ $# -gt 0 ]]; do
#    case $1 in
#        -e|enable)          ENABLE=1 ;;
#        -d|disable)         DISABLE=1 ;;
#        -en|enable-now)     ENABLE_NOW=1 ;;
#        -dn|disable-now)    DISABLE_NOW=1 ;;
#        -s|start)           START=1 ;;
#        -k|stop)            STOP=1 ;;
#        -r|restart)         RESTART=1 ;;
#        -rl|reload)         COMMAND=$RELOAD_CMD; ARGS=$RELOAD_ARGS; break ;;
#        -st|status)         STATUS=1 ;;
#        -cc|chk_conf)       COMMAND=$CHK_CONF_CMD; ARGS=$CHK_CONF_ARGS; break ;;
#        -j|journ)           COMMAND="journalctl"; HELP_EXIT_RC=0; ARGS="-xeu ${SERVICE}.service"; break ;;
#        -h|--help)          COMMAND="help"; HELP_EXIT_RC=0; break ;;
#        *) echo -e "\n ${bred}Неизвестный аргумент: ${byellow}$1${bred}!${nc}" >&2; COMMAND="help"; HELP_EXIT_RC=1;;
#    esac
#    shift
#done

### Основная логика
###################
#echo -e ${nc}
#if [[ "$ENABLE" -eq 1 ]]; then      COMMAND="run_cmd"; ARGS="enable"; fi
#if [[ "$DISABLE" -eq 1 ]]; then     COMMAND="run_cmd"; ARGS="disable"; fi
#if [[ "$ENABLE_NOW" -eq 1 ]]; then  COMMAND="run_cmd"; ARGS="enable --now"; fi
#if [[ "$DISABLE_NOW" -eq 1 ]]; then COMMAND="run_cmd"; ARGS="disable --now"; fi
#if [[ "$START" -eq 1 ]]; then       COMMAND="run_cmd"; ARGS="start"; fi
#if [[ "$STOP" -eq 1 ]]; then        COMMAND="run_cmd"; ARGS="stop"; fi
#if [[ "$RESTART" -eq 1 ]]; then     COMMAND="run_cmd"; ARGS="restart"; fi
#if [[ "$STATUS" -eq 1 ]]; then      COMMAND="run_cmd"; ARGS="status"; fi
##if [[ "$HELP" -eq 1 ]]; then        COMMAND="help"; fi
#
#if [[ "$NO_ARGS" -eq 1 ]]; then echo -e " ${bred}Пустые аргументы [${byellow}ОПЦИИ${bred}]! ${bnc}\n${nc}"; COMMAND="help"; fi
#if [[ "$COMMAND" == "help" ]]; then show_help "$HELP_EXIT_RC"; exit $HELP_EXIT_RC; fi
#if [[ -z "$COMMAND" ]]; then show_help; else $COMMAND $ARGS; fi

#latest_installed_kernel() {
#    rpm -q --last kernel 2>/dev/null \
#        | awk '/^kernel-/{print $1; exit}' \
#        | sed 's/^kernel-//'
#}
#update_kernel() {
#    local ver="${KERNEL_VERSION:-}"
#    local pkg_ver
#    local arch
#
#    arch="$(uname -m)"
#
#    if [ -z "$ver" ]; then
#        log "Версия ядра не указана: обновление до последней доступной."
#        confirm "Обновить ядро и заголовки до последней версии?" || {
#            err "Обновление ядра отменено."
#            return 1
#        }
#        dnf install -y kernel kernel-devel kernel-headers || {
#            err "Не удалось установить последнее ядро."
#            return 1
#        }
#        ver="$(latest_installed_kernel)"
#        if [ -z "$ver" ]; then
#            err "Не удалось определить установленную версию ядра."
#            return 1
#        fi
#        log "Установлено ядро: $ver"
#    elif [ -d "/lib/modules/${ver}/build" ]; then
#        log "Заголовки для ядра $ver уже установлены."
#    else
#        pkg_ver="$ver"
#        case "$pkg_ver" in
#            *."$arch") pkg_ver="${pkg_ver%.*}" ;;
#        esac
#
#        log "Установка ядра $pkg_ver и заголовков."
#        dnf install -y "kernel-${pkg_ver}" "kernel-devel-${pkg_ver}" kernel-headers || {
#            err "Не удалось установить ядро $pkg_ver."
#            return 1
#        }
#    fi
#
#    if [ ! -d "/lib/modules/${ver}/build" ]; then
#        err "Заголовки для ядра $ver не найдены после установки."
#        return 1
#    fi
#
#    KERNEL_VERSION="$ver"
#    log "Целевое ядро для сборки: $KERNEL_VERSION."
#}
