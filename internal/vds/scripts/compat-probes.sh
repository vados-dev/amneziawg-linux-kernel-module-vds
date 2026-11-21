#!/usr/bin/env bash
# Добавляет зонды AWG_HAVE_* к шим-блокам в compat.h.
# Каждый якорь уникален в файле; если апстрим менял compat.h и якорь исчез —
# скрипт падает с именем якоря. Повторный запуск безопасен (guard уже есть — skip).
set -euo pipefail
f="${1:?usage: compat-probes.sh path/to/compat.h}"
[ -f "$f" ] || { echo "::error::compat.h not found: $f"; exit 1; }
echo "Applying compat probes to $(basename "$f")"

guard() {
  local anchor="$1" flag="$2" nline nif line
  nline="$(grep -nF -- "$anchor" "$f" | head -n1 | cut -d: -f1)" || true
  if [ -z "$nline" ]; then
    echo "::error::anchor not found in compat.h: '$anchor' — апстрим менял compat.h, проверьте блок"
    exit 1
  fi
  # Ближайший предыдущий #if (только #if с пробелом/скобкой, не #ifdef/#ifndef).
  nif="$(sed -n "1,${nline}p" "$f" | grep -nE '^#if[ (]' | tail -n1 | cut -d: -f1)"
  if [ -z "$nif" ]; then
    echo "::error::no #if above anchor: '$anchor'"; exit 1
  fi
  line="$(sed -n "${nif}p" "$f")"
  if grep -q 'AWG_HAVE' <<<"$line"; then
    echo "  already guarded: $flag (line $nif)"
    return 0
  fi
  sed -i "${nif}s|\$| \&\& !defined(${flag})|" "$f"
  echo "  guard added: $flag (line $nif: $line)"
}

guard '#define timer_container_of from_timer' 'AWG_HAVE_TIMER_CONTAINER_OF'
guard 'struct sockaddr_inet {' 'AWG_HAVE_SOCKADDR_INET'
guard 'static inline void netif_threaded_enable(struct net_device *dev)' 'AWG_HAVE_NETIF_THREADED_ENABLE'
guard '#define COMPAT_CANNOT_USE_RTNL_NEWLINK_PARAMS' 'AWG_HAVE_RTNL_NEWLINK_LINK_NET'
guard '#define CHACHA_KEY_WORDS' 'AWG_HAVE_CHACHA_STATE'
guard '#define WQ_PERCPU 0' 'AWG_HAVE_WQ_PERCPU'

# Финальная сверка: все шесть флагов обязаны присутствовать.
missing=0
for flag in AWG_HAVE_TIMER_CONTAINER_OF AWG_HAVE_SOCKADDR_INET AWG_HAVE_NETIF_THREADED_ENABLE \
            AWG_HAVE_RTNL_NEWLINK_LINK_NET AWG_HAVE_CHACHA_STATE AWG_HAVE_WQ_PERCPU; do
  grep -q "$flag" "$f" || { echo "::error::flag missing after patching: $flag"; missing=1; }
done
[ "$missing" = 0 ] || exit 1
echo "compat probes: OK"
