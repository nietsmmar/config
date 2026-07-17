#!/usr/bin/env bash
# ── internet-limit configuration ─────────────────────────────────────────────
# Edit this file to change behaviour. Changes take effect within one minute:
# the enforcement service re-reads this file on every run. No `nixos-rebuild`
# is needed unless you change the systemd wiring in nixos/configuration.nix.
#
# Times are 24h "HH:MM". Windows may cross midnight (start > end is fine).
# ─────────────────────────────────────────────────────────────────────────────

# The Linux user whose desktop apps (Telegram) are managed.
LIMIT_USER="xunil"

# ── Evening internet cutoff ──────────────────────────────────────────────────
# All networking is disabled between these times (crosses midnight).
# A Telegram window (below) temporarily re-enables the network even in here.
INTERNET_OFF_START="19:00"
INTERNET_OFF_END="07:00"

# ── Workday distraction blocks ───────────────────────────────────────────────
# Distraction domains + the Telegram app are blocked during these hours,
# on these days. Days: Mon Tue Wed Thu Fri Sat Sun (space separated).
WORKDAY_START="08:00"
WORKDAY_END="18:00"
WORKDAYS="Mon Tue Wed Thu Fri Sat Sun"

# Domains blocked during the workday. Each entry is wildcarded, so it also
# blocks every subdomain (e.g. youtube.com also blocks www.youtube.com).
BLOCK_DOMAINS=(
  youtube.com
  youtu.be
  googlevideo.com     # YouTube's video CDN
  ytimg.com           # YouTube thumbnails/assets
  instagram.com
  cdninstagram.com    # Instagram's media CDN
  lichess.org
  fetlife.com
  linkedin.com
  licdn.com           # LinkedIn's CDN/assets
  web.whatsapp.com    # WhatsApp *browser* client only (mobile app unaffected)
  pr0gramm.com
)

# ── Telegram allowed windows ─────────────────────────────────────────────────
# The Telegram desktop app is killed during the workday, EXCEPT inside these
# windows. Inside a window the app is allowed AND the network is forced on
# (so windows also work during the evening cutoff). Format: "HH:MM-HH:MM".
# Use 24:00 to mean end-of-day / midnight.
TELEGRAM_WINDOWS=(
  "09:00-10:00"
  "13:00-14:00"
  "19:30-20:30"
  "23:30-24:00"
)

# Process names of the Telegram desktop app to kill (substring, case-insensitive).
TELEGRAM_PROCS=(Telegram telegram-desktop)

# Telegram's datacenter IP ranges. While Telegram is blocked, all traffic to
# these is REJECTed via iptables, so reopening the app can't connect.
# Source: https://core.telegram.org/resources/cidr.txt (refresh occasionally).
TELEGRAM_CIDRS=(
  91.108.56.0/22
  91.108.4.0/22
  91.108.8.0/22
  91.108.16.0/22
  91.108.12.0/22
  149.154.160.0/20
  91.105.192.0/23
  91.108.20.0/22
  185.76.151.0/24
)
TELEGRAM_CIDRS6=(
  2001:b28:f23d::/48
  2001:b28:f23f::/48
  2001:67c:4e8::/48
  2001:b28:f23c::/48
  2a0a:f280::/32
)
