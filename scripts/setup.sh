#!/usr/bin/env bash
# AmneziaWG (VDS) — установка зависимостей и модуля ядра.
# Работает автономно на чистой машине:
#   curl -fsSL <url>/setup.sh -o setup.sh && bash setup.sh -y
#
# Режимы:
#   (без флагов)   зависимости + модуль из готового пакета (копр/репозиторий)
#   -l             сборка из локального дерева (src/ рядом с этим скриптом)
#   -d             только зависимости
#   -k <ver>       целевое ядро, напр. 6.12.0-281.el10.x86_64
#                  (пустое значение или без флага = самое свежее из /lib/modules,
#                   в CI это обязательно: uname -r показывает ядро хоста, не контейнера)
#   -y             не спрашивать подтверждений
#   -s             тихая установка: не трогать сеть и сервисы (безопасно для CI)
#   --prebuilt     принудительно готовый пакет, даже если рядом есть дерево

set -euo pipefail

LOCAL_BUILD=0; DEPS_ONLY=0; ASSUME_YES=0; QUIET=0; FORCE_PREBUILT=0
KERNEL=""
MODULE_NAME="amneziawg"

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -l) LOCAL_BUILD=1 ;;
    -d) DEPS_ONLY=1 ;;
    -y) ASSUME_YES=1 ;;
    -s) QUIET=1 ;;
    -k)
      [ $# -ge 2 ] || { echo "[ERROR] [setup.sh] - флаг -k требует значение" >&2; usage; exit 2; }
      KERNEL="$2"
      shift ;;
    --prebuilt) FORCE_PREBUILT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] [setup.sh] - неизвестный аргумент: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log() { echo "[INFO] [setup.sh] - $*"; }
die() { echo "[ERROR] [setup.sh] - $*" >&2; exit 1; }

# Резолв целевого ядра. Пустое -k = самое свежее установленное ядро.
# Источник истины — /lib/modules, а не uname -r: внутри контейнера uname
# показывает ядро хоста-раннера (Ubuntu), а не ядро, установленное в образе.
if [ -z "$KERNEL" ]; then
  if [ -d /lib/modules ] && ls -1 /lib/modules | grep -q .; then
    KERNEL="$(ls -1 /lib/modules | sort -V | tail -n1)"
  else
    KERNEL="$(uname -r)"
  fi
fi
if [ ! -d "/lib/modules/$KERNEL" ]; then
  die "Ядро $KERNEL не установлено (/lib/modules/$KERNEL отсутствует); доступно: $(ls -1 /lib/modules 2>/dev/null | tr '\n' ' ')"
fi
log "Целевое ядро: $KERNEL"

confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  read -r -p "$1 [y/N] " a; [ "$a" = "y" ] || die "Отменено пользователем"
}

detect_os() {
  [ -r /etc/os-release ] || die "Нет /etc/os-release — не могу определить ОС"
  . /etc/os-release
  case "${ID:-unknown}" in
    debian|ubuntu|linuxmint|raspbian) PKG=apt ;;
    rhel|centos|rocky|almalinux|fedora|ol|sangoma) PKG=dnf ;;
    *) die "Неподдерживаемая ОС: ${ID:-unknown}" ;;
  esac
  log "ОС: ${PRETTY_NAME:-$OS_ID}, пакетный менеджер: $PKG"
}

install_deps_rhel() {
  dnf -y install dnf-plugins-core
  # EPEL есть не на всех членах семейства (на Fedora не нужен).
  rpm -q epel-release >/dev/null 2>&1 || dnf -y install epel-release || true
  dnf config-manager --set-enabled crb >/dev/null 2>&1 || true

  # Ядро: либо указанное -k, либо текущее (как уже стоит — devel гарантируем).
  log "Проверка и установка зависимостей."
  if [ "$KERNEL" != "$(uname -r)" ]; then
    dnf -y install "kernel-$KERNEL" "kernel-core-$KERNEL" "kernel-devel-$KERNEL" \
                   "kernel-devel-matched-$KERNEL" "kernel-headers-$KERNEL"
  else
    dnf -y install kernel-devel kernel-devel-matched kernel-headers
  fi
  dnf -y install gcc make git tar gzip which curl libmnl-devel pkgconf dkms
}

install_deps_debian() {
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential dkms libmnl-dev pkg-config curl tar gzip
  if [ "$KERNEL" != "$(uname -r)" ] || ! dpkg -s "linux-headers-$KERNEL" >/dev/null 2>&1; then
    apt-get install -y "linux-headers-$KERNEL" \
      || die "Заголовки ядра $KERNEL не найдены в репозиториях — установите вручную"
  fi
}

enable_copr() {
  # Копр tigro — источник готовых пакетов amneziawg для RHEL-семейства.
  local os_ver arch
  os_ver="$(rpm -E '%{rhel}' 2>/dev/null || true)"
  case "$os_ver" in ''|*[!0-9]*) os_ver=10 ;; esac
  arch="$(uname -m)"
  dnf copr enable -y tigro/amneziawg "centos-stream-${os_ver}-${arch}"
}

install_prebuilt_rhel() {
  enable_copr
  dnf clean all >/dev/null 2>&1 || true
  dnf makecache >/dev/null 2>&1 || true
  dnf -y install amneziawg-dkms
}

install_prebuilt_debian() {
  if ! apt-get install -y amneziawg-dkms 2>/dev/null; then
    die "Пакет amneziawg-dkms не найден. Добавьте репозиторий AmneziaWG по их инструкции и перезапустите скрипт."
  fi
}

build_local() {
  local script_dir src_dir ver
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  src_dir="$script_dir/src"
  [ -f "$src_dir/Makefile" ] || die "-l требует локального дерева: не найден $src_dir/Makefile"

  ver="$(make -C "$src_dir" print-version 2>/dev/null)" || die "Не удалось прочитать версию из src/version.h"
  [ -n "$ver" ] || die "WIREGUARD_VERSION не определён в src/version.h"
  log "Сборка из локального дерева: версия $ver, ядро $KERNEL"

  # dkms-install копирует исходники в /usr/src/amneziawg-<ver> и прописывает версию.
  make -C "$src_dir" dkms-install DESTDIR=/ "DKMSDIR=/usr/src/${MODULE_NAME}-${ver}" \
       "WIREGUARD_VERSION=$ver" >/dev/null

  dkms remove -m "$MODULE_NAME" -v "$ver" --all >/dev/null 2>&1 || true
  dkms add    -m "$MODULE_NAME" -v "$ver"
  dkms build  -m "$MODULE_NAME" -v "$ver" -k "$KERNEL"
  dkms install -m "$MODULE_NAME" -v "$ver" -k "$KERNEL"
  depmod -a "$KERNEL"

  local ko mver
  ko="$(find "/lib/modules/$KERNEL" -name 'amneziawg.ko*' | head -n1)"
  [ -n "$ko" ] || die "Модуль не найден в /lib/modules/$KERNEL после установки"
  mver="$(modinfo -F version "$ko" 2>/dev/null || true)"
  case "$mver" in
    *-vds) ;;
    *) die "Установлен не форковый модуль (version=$mver) — проверьте, нет ли копровского amneziawg-dkms" ;;
  esac
  log "Установлен модуль: $ko (version=$mver, vermagic=$(modinfo -F vermagic "$ko"))"
}

main() {
  detect_os
  if [ "$DEPS_ONLY" = "1" ]; then
    install_deps
    log "Готово: зависимости установлены (режим -d)."
    exit 0
  fi

  if [ "$ASSUME_YES" != "1" ]; then
    confirm "Установить зависимости и модуль $MODULE_NAME для ядра $KERNEL?"
  fi

  install_deps

  if [ "$LOCAL_BUILD" = "1" ] && [ "$FORCE_PREBUILT" != "1" ]; then
    build_local
  else
    case "$PKG" in
      dnf) install_prebuilt_rhel ;;
      apt) install_prebuilt_debian ;;
    esac
    log "Установлен готовый пакет amneziawg-dkms."
  fi

  if [ "$QUIET" = "1" ]; then
    log "Готово (режим -s: сеть и сервисы не тронуты)."
    exit 0
  fi

  # Полная установка на боевой машине: пересоздание интерфейсов оставляем админу,
  # но перечитываем модуль, если старый был загружен.
  if grep -q '^amneziawg' /proc/modules 2>/dev/null; then
    log "Модуль amneziawg уже загружен — удалите интерфейсы awg* и выполните modprobe -r amneziawg, затем modprobe amneziawg."
  else
    modprobe amneziawg || die "modprobe amneziawg не сработал — проверьте dmesg"
    log "Модуль загружен."
  fi
  log "Готово."
}

install_deps() {
  case "$PKG" in
    dnf) install_deps_rhel ;;
    apt) install_deps_debian ;;
  esac
}

main "$@"
