{ config, pkgs, ... }:

let
  ausschreibung-monitor = pkgs.writeShellScriptBin "ausschreibung-monitor" ''
    exec ${pkgs.python3}/bin/python3 ${./ausschreibung-monitor.py} "$@"
  '';
in
{
  users.groups.ausschreibung-monitor = { };
  users.users.ausschreibung-monitor = {
    isSystemUser = true;
    group = "ausschreibung-monitor";
  };

  # The real file deliberately remains outside the Nix store because it holds
  # the Slack webhook secret.  Install this template as /etc/ausschreibung-monitor.env.
  environment.etc."ausschreibung-monitor.env.example".source =
    ./ausschreibung-monitor.env.example;
  environment.etc."ausschreibung-monitor.json".source =
    ./ausschreibung-monitor.json;

  environment.systemPackages = [ ausschreibung-monitor ];

  systemd.services.ausschreibung-monitor = {
    description = "Find matching public tenders and report them to Slack";
    documentation = [
      "https://oeffentlichevergabe.de/documentation/swagger-ui/opendata/index.html"
    ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig = {
      ConditionPathExists = "/etc/ausschreibung-monitor.env";
      # Keep retrying after a resume where Wi-Fi is not ready yet.
      StartLimitIntervalSec = 0;
    };
    environment = {
      AUSSCHREIBUNG_STATE_FILE = "/var/lib/ausschreibung-monitor/state.json";
      AUSSCHREIBUNG_TIMEZONE = config.time.timeZone;
      AUSSCHREIBUNG_CONFIG_FILE = "/etc/ausschreibung-monitor.json";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "ausschreibung-monitor";
      Group = "ausschreibung-monitor";
      EnvironmentFile = "/etc/ausschreibung-monitor.env";
      ExecStart = "${ausschreibung-monitor}/bin/ausschreibung-monitor";
      StateDirectory = "ausschreibung-monitor";
      StateDirectoryMode = "0750";
      Restart = "on-failure";
      RestartSec = "5m";
      TimeoutStartSec = "20m";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  systemd.timers.ausschreibung-monitor = {
    description = "Run the public-tender report every morning";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 08:15:00 Europe/Berlin";
      # A missed run fires when the laptop next boots or resumes.
      Persistent = true;
      AccuracySec = "5m";
      RandomizedDelaySec = "5m";
      Unit = "ausschreibung-monitor.service";
    };
  };
}
