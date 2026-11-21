#!/usr/bin/env bash
# AmneziaWG (VDS) — установка зависимостей и модуля ядра.
# Работает автономно на чистой машине:
#   curl -fsSL <url>/setup.sh -o setup.sh && bash setup.sh -t v<версия>-vds -y
#
# Режимы:
#   (без флагов)   в репозитории: зависимости + готовый пакет (copr);
#                  standalone: сборка из скачанного дерева (см. -t)
#   -l             сборка из локального дерева (src/ рядом с этим скриптом)
#   -d             только зависимости
#   -k <ver>       целевое ядро, напр. 6.12.0-281.el10.x86_64
#                  (пустое значение или без флага = самое свежее из /lib/modules,
#                   в CI это обязательно: uname -r показывает ядро хоста, не контейнера)
#   -y             не спрашивать подтверждений
#   -s             тихая установка: не трогать сеть и сервисы (безопасно для CI)
#   -t <ref>       ref для standalone: тег v*-vds или ветка
#                  (master/stable/testing-*; по умолчанию master)
#   --prebuilt     принудительно готовый пакет (апстрим из copr, БЕЗ правок VDS)
#   --remove       удалить модуль (DKMS) и запись автозагрузки

set -euo pipefail

# Common vars
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "${SELF}")"
ME_SELF="${SELF##*/}"
ME_CLEAN="${ME_SELF%.*}"
PROGRAM="${0##*/}"
ARGS=( "$@" )
PARENT_DIR="$(dirname "${SELF_DIR}")"

if [ -t 0 ]; then
  cmd()  { printf '  [\033[1;33m✨\033[0m]\033[1m %s \033[0m\n' "$*" >&2; "$@"; }
  log()  { printf ' \033[1;34m 📋 INFO:\033[0;8m [%s] - %s.\033[0m\n' "$PROGRAM" "$*"; }
  warn() { printf ' \033[1;33m ⚡ WARN:\033[0;1m [%s] - %s.\033[0m\n' "$PROGRAM" "$*" >&2; }
  err()  { printf ' \033[0;31m ⚫ ERROR:\033[0;1m [%s] - %s!\033[0m\n' "$PROGRAM" "$*" >&2; }
  die()  { printf ' \033[1;31m ❌ CRITICAL:\033[0;1m [%s] - %s!\033[0m\n' "$PROGRAM" "$*" >&2; exit 1; }
else
  cmd()  { printf '  [*] %s\n' "$*" >&2; "$@"; }
  log()  { printf ' [INFO] [%s] - %s.\n' "$PROGRAM" "$*"; }
  warn() { printf ' [WARN] [%s] - %s.\n' "$PROGRAM" "$*" >&2; }
  err()  { printf ' [ERROR] [%s] - %s!\n' "$PROGRAM" "$*" >&2; }
  die()  { printf ' [CRITICAL] [%s] - %s!\n' "$PROGRAM" "$*" >&2; exit 1; }
fi

LOCAL_BUILD=0; DEPS_ONLY=0; ASSUME_YES=0; QUIET=0; FORCE_PREBUILT=0; REMOVE=0

KERNEL=""
MODULE_NAME="amneziawg"
amf="/etc/modules-load.d/${MODULE_NAME}.conf"
STANDALONE=0
REF_EXPLICIT=0
# Ref для standalone-установки: тег v*-vds, ветка master/stable/testing-<ver>-vds.
# Влияет только когда скрипт запущен вне репозитория.
REF="${REF:-master}"

usage() { sed -n '2,19p' "${SELF}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -l) LOCAL_BUILD=1 ;;
    -d) DEPS_ONLY=1 ;;
    -y) ASSUME_YES=1 ;;
    -s) QUIET=1 ;;
    -k)
      [ $# -ge 2 ] || { err "флаг -k требует значение"; usage; exit 2; }
      KERNEL="$2"
      shift ;;
    --prebuilt) FORCE_PREBUILT=1 ;;
    --remove) REMOVE=1 ;;
    -t)
      [ $# -ge 2 ] || { err "флаг -t требует значение"; usage; exit 2; }
      REF="$2"
      REF_EXPLICIT=1
      shift ;;
    --ref)
      [ $# -ge 2 ] || { err "флаг --ref требует значение"; usage; exit 2; }
      REF="$2"
      REF_EXPLICIT=1
      shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "неизвестный аргумент: $1"; usage; exit 2 ;;
  esac
  shift
done

# --- Локация: репозиторий или standalone? ---
# Скрипт скачан отдельно (curl/wget), если рядом с ним нет src/.
# Тогда тянем тарбол нужного рефа во временную папку и работаем оттуда;
# исходники всё равно переезжают в /usr/src/<MODULE>-<ver> через dkms-install,
# поэтому временную папку можно смело удалять по завершении (trap EXIT).
REPO_ROOT=""
if [ "$REMOVE" = "1" ]; then
  # Случай 1: запрошено удаление (--remove). Дерево исходников не нужно,
  # REPO_ROOT остаётся пустым — ничего не делаем.
  :
elif [ -d "${PARENT_DIR}/src" ]; then
  # Случай 2: скрипт лежит в репозитории (рядом есть src/).
  # Дерево уже на диске — просто запоминаем его путь.
  REPO_ROOT="${PARENT_DIR}"
else
  # Случай 3: скрипт скачан отдельно, исходников рядом нет.
  STANDALONE=1
  if [ "$REF_EXPLICIT" = "0" ]; then
    log "Ref не задан явно (-t) — использую master по умолчанию."
    warn "Если этот setup.sh скачан с тега, передайте -t v<версия>-vds, чтобы версии совпали."
  fi
  log "Standalone-режим: скачиваю дерево для ref '${REF}'"
  case "${REF}" in
    master|stable|testing-*)
      tarball_url="https://github.com/vados-dev/amneziawg-linux-kernel-module-vds/archive/refs/heads/${REF}.tar.gz"
      ;;
    v*-vds)
      tarball_url="https://github.com/vados-dev/amneziawg-linux-kernel-module-vds/archive/refs/tags/${REF}.tar.gz"
      ;;
    *)
      die "Неизвестный ref '${REF}': теги v<версия>-vds, ветки master/stable/testing-<версия>-vds"
      ;;
  esac
  REPO_ROOT="$(mktemp -d -t amneziawg-src-XXXXXX)"
  trap 'rm -rf "${REPO_ROOT}"' EXIT
  if ! curl -fsSL "${tarball_url}" | tar -xz -C "${REPO_ROOT}" --strip-components=1; then
    die "Не удалось скачать дерево для ref '${REF}' — проверьте имя (теги: v<версия>-vds)"
  fi
  log "Дерево скачано: ${REPO_ROOT}"

  # Контроль рассинхрона: для тега версия в дереве обязана совпадать с ref.
  if case "${REF}" in v*-vds) true ;; *) false ;; esac; then
    cur="$(tr -d '[:space:]' < "${REPO_ROOT}/internal/config/current" 2>/dev/null || true)"
    expected="${REF#v}"
    if [ -n "$cur" ] && [ "$cur" != "$expected" ]; then
      die "Рассинхрон: ref '${REF}', а версия в дереве '${cur}' — сообщите об этом"
    fi
  fi
fi

# Резолв целевого ядра. Пустое -k = самое свежее установленное ядро.
# Источник истины — /lib/modules, а не uname -r: внутри контейнера uname
# показывает ядро хоста-раннера (Ubuntu), а не ядро, установленное в образе.
# В выборку идут только директории: файлы и symlinks (вроде «current»)
# в сортировку не попадают и не могут сбить выбор.
if [ -z "$KERNEL" ]; then
  if [ -d /lib/modules ] && [ -n "$(ls -d /lib/modules/*/ 2>/dev/null)" ]; then
    KERNEL="$(for d in /lib/modules/*/; do basename "$d"; done | sort -V | tail -n1)"
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
  [ -t 0 ] || die "Нет интерактивного терминала — используйте -y"
  read -r -p "$1 [y/N] " a; [ "$a" = "y" ] || die "Отменено пользователем"
}

detect_os() {
  [ -r /etc/os-release ] || die "Нет /etc/os-release — не могу определить ОС"
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-unknown}" in
    debian|ubuntu|linuxmint|raspbian) PKG=apt ;;
    rhel|centos|rocky|almalinux|fedora|ol|sangoma) PKG=dnf ;;
    *) die "Неподдерживаемая ОС: ${ID:-unknown}" ;;
  esac
  log "ОС: ${PRETTY_NAME:-$ID}, пакетный менеджер: $PKG"
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
  local src_dir ver
  src_dir="${REPO_ROOT}/src"
  [ -f "$src_dir/Makefile" ] || die "Сборка требует локального дерева: не найден $src_dir/Makefile"

  ver="$(make -s -C "$src_dir" print-version 2>/dev/null | tail -n1)"
  [ -n "$ver" ] || die "WIREGUARD_VERSION не определён в src/version.h"
  log "Сборка из дерева ${REPO_ROOT}: версия $ver, ядро $KERNEL"

  # dkms-install копирует исходники в /usr/src/amneziawg-<ver> и прописывает версию.
  make -C "$src_dir" dkms-install DESTDIR=/ "DKMSDIR=/usr/src/${MODULE_NAME}-${ver}" \
       "WIREGUARD_VERSION=$ver" >/dev/null

  dkms remove -m "$MODULE_NAME" -v "$ver" --all >/dev/null 2>&1 || true
  cmd dkms add    -m "$MODULE_NAME" -v "$ver"
  cmd dkms build  -m "$MODULE_NAME" -v "$ver" -k "$KERNEL"
  cmd dkms install -m "$MODULE_NAME" -v "$ver" -k "$KERNEL"
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

remove_dkms_module() {
    # Удаляем все установленные версии модуля из DKMS.
    local found=0
    if rpm -q amneziawg-dkms >/dev/null 2>&1; then
      warn "Модуль установлен пакетом amneziawg-dkms — корректнее удалить его через 'dnf remove amneziawg-dkms'."
    fi
    while read -r ver _; do
        [ -n "$ver" ] || continue
        found=1
        cmd dkms remove -m "$MODULE_NAME" -v "$ver" --all
    done < <(dkms status 2>/dev/null | awk -F'[ /,:]' -v m="$MODULE_NAME" '$1==m {print $2}')
    [ "$found" = "1" ] || log "Модуль в DKMS не найден — удалять нечего."
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

load_module() {
    local out
    log "Выполняю: modprobe amneziawg"
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

main() {
  detect_os
  if [ "$REMOVE" = "1" ]; then
    if [ "$ASSUME_YES" != "1" ]; then
      confirm "Удалить модуль $MODULE_NAME (DKMS) и запись автозагрузки $amf?"
    fi
    # Выгрузить, если загружен (интерфейсы awg* — на совести админа).
    if grep -q '^amneziawg' /proc/modules 2>/dev/null; then
      if out="$(ls /sys/module/amneziawg/holders 2>/dev/null)" && [ -n "$out" ]; then
        die "Модуль используется: держатели — $out. Удалите интерфейсы awg* и повторите."
      fi
      cmd modprobe -r amneziawg || warn "modprobe -r amneziawg не сработал — модуль, возможно, в использовании"
    fi
    remove_dkms_module
    del_awg_from_modules
    depmod -a "$KERNEL"
    log "Удаление завершено."
    exit 0
  fi
  if [ "$DEPS_ONLY" = "1" ]; then
    install_deps
    log "Готово: зависимости установлены (режим -d)."
    exit 0
  fi

  if [ "$ASSUME_YES" != "1" ]; then
    confirm "Установить зависимости и модуль $MODULE_NAME для ядра $KERNEL?"
  fi

  install_deps

  if { [ "$LOCAL_BUILD" = "1" ] || [ "$STANDALONE" = "1" ]; } && [ "$FORCE_PREBUILT" != "1" ]; then
    build_local
  else
    if [ "$STANDALONE" = "1" ]; then
      warn "--prebuilt в standalone ставит апстримный пакет amneziawg-dkms из copr — БЕЗ правок VDS."
    fi
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
  # модуль перечитываем через check_module; если уже был загружен — это может
  # быть старая версия, админу виднее, перезапускать ли интерфейсы.
  if grep -q '^amneziawg' /proc/modules 2>/dev/null; then
    warn "Модуль уже загружен — возможно, это старая версия. Для перезагрузки: удалите интерфейсы awg*, затем modprobe -r amneziawg и modprobe amneziawg."
  fi
  check_module || die "Проверка/загрузка модуля не прошли"
  log "Готово."
}

install_deps() {
  case "$PKG" in
    dnf) install_deps_rhel ;;
    apt) install_deps_debian ;;
  esac
}

main "$@"
