# Ausschreibungsmonitor

The laptop downloads the official German Bekanntmachungsservice daily export,
matches new or corrected calls for competition, enriches likely matches with
their deadline and document link, and posts a ranked report to Slack.

The timer runs at 08:15 Europe/Berlin. `Persistent=true` makes systemd run a
missed job when the laptop next boots or resumes. The monitor remembers its last
successfully reported publication date, so it catches up every missed day.

## One-time setup

1. Create a Slack app, enable **Incoming Webhooks**, and add a webhook for the
   destination channel.
2. Install the configuration template and edit its matching rules:

   ```sh
   sudo install -m 600 \
     /home/xunil/dev/config/nixos/services/ausschreibung-monitor.env.example \
     /etc/ausschreibung-monitor.env
   sudoedit /etc/ausschreibung-monitor.env
   ```

3. Activate the laptop configuration:

   ```sh
   sudo nixos-rebuild switch --flake /home/xunil/dev/config/nixos#laptop
   ```

4. Run and inspect the first report immediately:

   ```sh
   sudo systemctl start ausschreibung-monitor.service
   journalctl -u ausschreibung-monitor.service -n 100 --no-pager
   ```

Useful checks:

```sh
systemctl list-timers ausschreibung-monitor.timer
sudo systemctl status ausschreibung-monitor.service
```

The webhook stays in `/etc/ausschreibung-monitor.env`, not in Git or the Nix
store. Non-secret keywords, CPV codes, exclusions, and regional filters live in
`ausschreibung-monitor.json`. Runtime state lives in
`/var/lib/ausschreibung-monitor/state.json`.
