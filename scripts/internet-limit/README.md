# internet-limit

Time-based self-control for internet access, distraction sites, and the
Telegram desktop app. Enforced every minute by a root systemd timer.

## What it does (per the current `config.sh`)

- **19:00–07:00** — all networking is disabled (`nmcli networking off`),
  automatically restored at 07:00.
- **08:00–18:00, every day** — these sites are DNS-blackholed in every
  browser: YouTube, Instagram, lichess, FetLife, WhatsApp Web; and the
  Telegram desktop app is killed.
- **Telegram windows** (default 13:00–14:00 and 23:30–00:00) — Telegram is
  allowed and the network is forced on, even during the evening cutoff.

## Usage

```
internet-limit status        # what's allowed right now
internet-limit pause 30m     # lift all limits for a while (30m/1h/45…)
internet-limit resume        # cancel a pause
```

`pause`/`resume` take effect within ~1 minute (next enforcement tick).

## Changing behaviour

Edit `config.sh` — times, days, blocked domains, and Telegram windows.
Changes apply within a minute; **no rebuild needed**.

You only need `sudo nixos-rebuild switch --flake ~/dev/config/nixos#` if you
change the systemd wiring in `nixos/configuration.nix` (or on first install).

## How it works

- Domain blocking: NetworkManager runs a local `dnsmasq`; the script writes
  `address=/domain/0.0.0.0` rules to
  `/etc/NetworkManager/dnsmasq.d/internet-limit.conf` and reloads DNS.
- Evening cutoff: `nmcli networking off/on`.
- Telegram: `pkill` of the app **and** an `iptables` REJECT of Telegram's
  datacenter IP ranges (`TELEGRAM_CIDRS`), so reopening the app can't connect.
  Ranges come from https://core.telegram.org/resources/cidr.txt — refresh the
  list in `config.sh` if Telegram ever adds new datacenters.

The enforcement service (`systemd.services.internet-limit`, run by
`systemd.timers.internet-limit`) reads the repo files directly, so it always
reflects the committed config.
