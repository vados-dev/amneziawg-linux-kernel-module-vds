#!/usr/bin/env bash
#
# Installs the AmneziaWG kernel module and tools, the prerequisite for an AmneziaWG inbound's "kernel mode" (internal/amneziawgkern).
# Without it the panel refuses to enable the setting and says why.
# Verified on Centos 10 stream and Debian 13 (trixie), kernel 7.1.11-x64v3-xanmod1, x86_64.
#set -eu
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

# Flags
INST_DEPS=0; RM_DEPS=0; SETUP_MOD=0; ADD_MOD=0; REINSTALL=0; UNINSTALL=0; HELP=0; HELP_EXIT_RC=0
#####################################################################################
AMNEZIAWG_MODULE_CONF="/etc/modules-load.d/amneziawg.conf"
WIREGUARD_MODULE_CONF="/etc/modules-load.d/wireguard.conf"
DTSTAMP="$(date +'%Y%m%d%H%M')"
mod_tmp_ver="3.1-${DTSTAMP}"
mod_repo_owner="vados-dev"
#mod_repo_owner="amnezia-vpn"
mod_repo="amneziawg-linux-kernel-module-vds"
#mod_repo="amneziawg-linux-kernel-module"
mod_branch="master"

setup_tmp="${cur_dir}/${mod_repo}-${mod_tmp_ver}"

KERNEL="$(uname -r)"
[[ "$os_type" == "deb" ]] && SRC_DIR="${SRC_DIR:-/usr/local/src}" || SRC_DIR="${SRC_DIR:-/usr/src}"

DTSTAMP="$(date +'%Y%m%d%H%M')"
mod_tmp_ver="3.1-${DTSTAMP}"

MODULE_OWNER="amnezia-vpn"
MODULE_REPO="amneziawg-linux-kernel-module"
MODULE_URL="https://github.com/${MODULE_OWNER}/${MODULE_REPO}.git"
TOOLS_OWNER="amnezia-vpn"
TOOLS_REPO="amneziawg-tools"
TOOLS_URL="https://github.com/${MODULE_OWNER}/${MODULE_REPO}.git"

# Pinned to tested releases and verified by commit, since this runs as root. Module and tools must share the 3.x series:
# 1.0 tools send u32 H1-H4 and `awg setconf` then fails with "Invalid argument".
MODULE_TAG="v3.1.20260906"
MODULE_COMMIT="4569c4c67f3a57414969260cafbbd04694fbaae0"
TOOLS_TAG="v3.1.20260812"
TOOLS_COMMIT="ee0f0a9aa34ff0a0da4b3433b9512781cfe02843"

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
        deps=(kernel-headers-$(uname -r) kernel-devel-$(uname -r) amneziawg-tools amneziawg-dkms mc git make curl wget libmnl-dev pkg-config fail2ban firewalld firewalld-filesystem nftables python3 python3-pip pythov-venv qrencode)
        confirm "Установить репозитории?" "y" && install_dnf_repos        
        confirm "Проверить обновления?" "y" && check_dnf_updates
        log "Проверка зависимостей: ${deps[@]}..."
        check_deps "${deps[@]}" > /dev/null 2>&1 && log "Зависимости установлены" || die "Зависимости не установлены!"
    elif [[ "$os_type" == "deb" ]]; then
        log "Зависимости"
        export DEBIAN_FRONTEND=noninteractive
        deps="mc make curl wget ca-certificates dkms build-essential git libmnl-dev pkg-config iproute2 golang-go python3 python3-venv python3-pip nftables"
        #iptables
        apt-get update -qq
        # --no-install-recommends: иначе python3-pip тянет build-essential, gcc, g++, binutils, python3-dev — семьдесят пакетов вместо десяти.
        # У cryptography на amd64/arm64 есть готовые wheel, компилятор ей не нужен.
        apt-get install -y -qq --no-install-recommends $deps
        #make curl ca-certificates iproute2 iptables python3 python3-venv python3-pip golang-go
        log "Базовые пакеты (включая golang-go из репозитория)."
    fi
}

log "Installing build dependencies"
install_deps

# A clang-built kernel makes DKMS invoke the module build with LLVM=1, which
# fails outright when only gcc is present. /proc/version names the compiler.
if grep -qi clang /proc/version; then
	log "Kernel was built with clang; installing the LLVM toolchain to match"
	apt-get install -y -qq clang lld llvm
fi

log "Module $MODULE_TAG, tools $TOOLS_TAG", "Kernel: $KERNEL"
[ -d "/lib/modules/$KERNEL/build" ] || die "Kernel headers missing; install linux-headers-${KERNEL}!"

if [[ "$os_type" == "rhel" ]]; then
    git clone https://github.com/${mod_repo_owner}/${mod_repo}.git -b ${mod_branch} ${setup_tmp} > /dev/null 2>&1 | true
#    git clone https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git ./setup-3.1
#exit 0
    local mod_ver
    cd ${setup_tmp}/src && \
    ! command -v make print-version > /dev/null 2>&1 && mod_ver="$(make print-version)" || mod_ver="$(cat version.h | grep "define WIREGUARD_VERSION" | awk -F'[/" ]+' '{print $3}')" && \
#echo $mod_ver
#exit 0
    sudo make dkms-install && \
    sudo dkms install -m amneziawg -v ${mod_ver}
    add_awg_to_modules
#    add_wg_to_modules
elif [[ "$os_type" == "deb" ]]; then
    mkdir -p "$SRC_DIR"
    cd "$SRC_DIR"
    rm -rf amneziawg-linux-kernel-module amneziawg-tools
    git clone -q --depth 1 --branch "$MODULE_TAG" "$MODULE_REPO"
    git clone -q --depth 1 --branch "$TOOLS_TAG" "$TOOLS_REPO"
    [ "$(git -C amneziawg-linux-kernel-module rev-parse HEAD)" = "$MODULE_COMMIT" ] || die "module $MODULE_TAG is not commit $MODULE_COMMIT"
    [ "$(git -C amneziawg-tools rev-parse HEAD)" = "$TOOLS_COMMIT" ] || die "tools $TOOLS_TAG is not commit $TOOLS_COMMIT"
fi

MODULE_SRC="$SRC_DIR/amneziawg-linux-kernel-module/src"

log "Building the module via DKMS"
cd "$MODULE_SRC"
rm -rf /usr/src/amneziawg-1.0.0
make dkms-install
dkms status -m amneziawg -v 1.0.0 | grep -q . || dkms add -m amneziawg -v 1.0.0
dkms build -m amneziawg -v 1.0.0
dkms install -m amneziawg -v 1.0.0 --force

export ccflags-y += -Wno-redundant-decls

log "Loading the module"
modprobe amneziawg
lsmod | grep -q '^amneziawg' || die "module did not load"

log "Building amneziawg-tools"
cd "$SRC_DIR/amneziawg-tools/src"
make
make install

log "Done"
printf '  module: %s\n' "$(dkms status -m amneziawg)"
printf '  tools:  %s\n' "$(awg --version)"
printf '\nEnable "Kernel mode" on the AmneziaWG inbound in the panel to use it.\n'
printf 'DKMS rebuilds the module on kernel upgrades; Secure Boot hosts must sign it.\n'
