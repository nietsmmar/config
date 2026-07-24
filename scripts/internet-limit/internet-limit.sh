#!/usr/bin/env bash
# ── internet-limit ───────────────────────────────────────────────────────────
# Time-based self-control for internet / distraction sites / Telegram.
#
#   internet-limit enforce        apply the rules for "now" (run by a root timer)
#   internet-limit pause [DUR]     temporarily disable all limits (default 30m)
#   internet-limit resume          cancel a pause
#   internet-limit status          show what is / isn't allowed right now
#
# DUR accepts e.g. 30m, 45, 1h, 90m, 2h. Behaviour is configured in config.sh.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$SELF_DIR/config.sh"

DNSMASQ_CONF="/etc/NetworkManager/dnsmasq.d/internet-limit.conf"
TG_CHAIN="INTERNET_LIMIT_TG"
PAUSE_FILE="/home/${LIMIT_USER}/.local/state/internet-limit/pause-until"
LOG_TAG="internet-limit"

log() { logger -t "$LOG_TAG" -- "$*" 2>/dev/null || true; }

# ── time helpers ─────────────────────────────────────────────────────────────
# Minutes-since-midnight for an "HH:MM" string (24:00 -> 1440).
to_min() { local t=$1; echo $(( 10#${t%%:*} * 60 + 10#${t##*:} )); }

now_min() { local n; n=$(date +%H:%M); to_min "$n"; }

# in_window NOW START END  -> success if NOW is within [START,END) (may wrap).
in_window() {
  local now=$1 s=$2 e=$3
  if (( s <= e )); then (( now >= s && now < e )); else (( now >= s || now < e )); fi
}

today_is_workday() {
  local dow; dow=$(LC_ALL=C date +%a)   # Mon, Tue, ... (locale-independent)
  [[ " $WORKDAYS " == *" $dow "* ]]
}

# ── state predicates ─────────────────────────────────────────────────────────
is_paused() {
  [[ -f "$PAUSE_FILE" ]] || return 1
  local until; until=$(cat "$PAUSE_FILE" 2>/dev/null || echo 0)
  [[ "$until" =~ ^[0-9]+$ ]] || return 1
  (( $(date +%s) < until ))
}

in_evening_off() {
  local n; n=$(now_min)
  in_window "$n" "$(to_min "$INTERNET_OFF_START")" "$(to_min "$INTERNET_OFF_END")"
}

in_workday() {
  today_is_workday || return 1
  local n; n=$(now_min)
  in_window "$n" "$(to_min "$WORKDAY_START")" "$(to_min "$WORKDAY_END")"
}

in_telegram_window() {
  local n w s e; n=$(now_min)
  for w in "${TELEGRAM_WINDOWS[@]}"; do
    s=$(to_min "${w%%-*}"); e=$(to_min "${w##*-}")
    if in_window "$n" "$s" "$e"; then return 0; fi
  done
  return 1
}

# ── enforcement actions (root) ───────────────────────────────────────────────
apply_network() {   # $1 = "off" | "on"
  local want=$1 state
  state=$(nmcli -t -f STATE general status 2>/dev/null || echo unknown)
  if [[ $want == off ]]; then
    if [[ $state != disconnected* && $state != asleep* ]]; then
      nmcli networking off && log "networking OFF"
    fi
  else
    # networking enabled? nmcli networking shows enabled/disabled
    if [[ $(nmcli networking 2>/dev/null) == disabled ]]; then
      nmcli networking on && log "networking ON"
    fi
  fi
}

apply_domain_blocks() {   # $1 = "block" | "clear"
  local want=$1 desired="" d
  if [[ $want == block ]]; then
    desired="# managed by internet-limit — do not edit by hand"$'\n'
    for d in "${BLOCK_DOMAINS[@]}"; do
      desired+="address=/${d}/0.0.0.0"$'\n'
      desired+="address=/${d}/::"$'\n'
    done
  fi
  # Only rewrite + reload when the content actually changes.
  mkdir -p "$(dirname "$DNSMASQ_CONF")"
  local current=""; [[ -f $DNSMASQ_CONF ]] && current=$(cat "$DNSMASQ_CONF")
  if [[ "$current" != "${desired%$'\n'}" && "$current" != "$desired" ]]; then
    printf '%s' "$desired" > "$DNSMASQ_CONF"
    nmcli general reload dns-full 2>/dev/null || nmcli general reload 2>/dev/null || true
    log "domain blocks: $want"
  fi
}

apply_telegram() {   # $1 = "kill" | "allow"
  [[ $1 == kill ]] || return 0
  # Case-insensitive substring match on the process name. Telegram runs under
  # a NixOS wrapper whose comm is ".Telegram-wrapp", so an exact (-x) match
  # misses it — match unanchored instead.
  local p
  for p in "${TELEGRAM_PROCS[@]}"; do
    if pgrep -u "$LIMIT_USER" -i "$p" >/dev/null 2>&1; then
      pkill -u "$LIMIT_USER" -i "$p" && log "killed $p"
    fi
  done
}

# Firewall Telegram's datacenter IPs so reopening the app can't connect.
# Rules live in a dedicated chain hooked into OUTPUT, so we can add/flush
# cleanly and idempotently.
apply_telegram_net() {   # $1 = "block" | "allow"
  local want=$1 ipt c
  for ipt in iptables ip6tables; do
    # Ensure the chain exists and is hooked into OUTPUT exactly once.
    $ipt -nL "$TG_CHAIN" >/dev/null 2>&1 || $ipt -N "$TG_CHAIN" 2>/dev/null || true
    $ipt -C OUTPUT -j "$TG_CHAIN" 2>/dev/null || $ipt -I OUTPUT -j "$TG_CHAIN" 2>/dev/null || true
  done

  if [[ $want == block ]]; then
    # Populate only if empty, to avoid resetting rules every minute.
    if [[ $(iptables -S "$TG_CHAIN" 2>/dev/null | wc -l) -le 1 ]]; then
      for c in "${TELEGRAM_CIDRS[@]}";  do iptables  -A "$TG_CHAIN" -d "$c" -j REJECT 2>/dev/null || true; done
      for c in "${TELEGRAM_CIDRS6[@]}"; do ip6tables -A "$TG_CHAIN" -d "$c" -j REJECT 2>/dev/null || true; done
      log "telegram network: blocked"
    fi
  else
    if [[ $(iptables -S "$TG_CHAIN" 2>/dev/null | wc -l) -gt 1 ]]; then
      iptables  -F "$TG_CHAIN" 2>/dev/null || true
      ip6tables -F "$TG_CHAIN" 2>/dev/null || true
      log "telegram network: allowed"
    fi
  fi
}

# ── commands ─────────────────────────────────────────────────────────────────
cmd_enforce() {
  if is_paused; then
    apply_network on
    apply_domain_blocks clear
    apply_telegram allow
    apply_telegram_net allow
    return 0
  fi

  local tg_window=0; in_telegram_window && tg_window=1

  # Network: off during the evening cutoff, unless a Telegram window overrides.
  if in_evening_off && (( ! tg_window )); then
    apply_network off
  else
    apply_network on
  fi

  # Distraction domains: blocked during the workday.
  if in_workday; then apply_domain_blocks block; else apply_domain_blocks clear; fi

  # Telegram app: killed AND its servers firewalled during the workday,
  # except inside a Telegram window.
  if in_workday && (( ! tg_window )); then
    apply_telegram kill
    apply_telegram_net block
  else
    apply_telegram allow
    apply_telegram_net allow
  fi
}

cmd_pause() {
  local dur=${1:-30m} secs
  case "$dur" in
    *h) secs=$(( 10#${dur%h} * 3600 ));;
    *m) secs=$(( 10#${dur%m} * 60 ));;
    *)  secs=$(( 10#$dur * 60 ));;   # bare number = minutes
  esac
  mkdir -p "$(dirname "$PAUSE_FILE")"
  echo $(( $(date +%s) + secs )) > "$PAUSE_FILE"
  echo "internet-limit paused until $(date -d "@$(cat "$PAUSE_FILE")" '+%H:%M') (${dur})."
  echo "Limits lift within ~1 minute. Run 'internet-limit resume' to cancel early."
}

cmd_resume() {
  rm -f "$PAUSE_FILE"
  echo "internet-limit resumed. Limits re-apply within ~1 minute."
}

cmd_status() {
  local n; n=$(now_min)
  printf 'Now: %s (%s)\n' "$(date +%H:%M)" "$(LC_ALL=C date +%a)"
  if is_paused; then
    printf 'State: PAUSED until %s\n' "$(date -d "@$(cat "$PAUSE_FILE")" '+%H:%M')"
    return 0
  fi
  local tg=0; in_telegram_window && tg=1
  local net="ON" dom="allowed" tgs="allowed"
  if in_evening_off && (( ! tg )); then net="OFF (evening cutoff)"; fi
  if in_workday; then dom="BLOCKED"; fi
  if in_workday && (( ! tg )); then tgs="BLOCKED (killed + firewalled)"; fi
  (( tg )) && tgs="allowed (in Telegram window)"
  printf 'Network:          %s\n' "$net"
  printf 'Distraction sites: %s\n' "$dom"
  printf 'Telegram app:      %s\n' "$tgs"
}

main() {
  case "${1:-enforce}" in
    enforce) cmd_enforce ;;
    pause)   cmd_pause "${2:-}" ;;
    resume)  cmd_resume ;;
    status)  cmd_status ;;
    *) echo "usage: internet-limit {enforce|pause [DUR]|resume|status}" >&2; exit 2 ;;
  esac
}
main "$@"
