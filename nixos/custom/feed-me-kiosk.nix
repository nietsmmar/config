{ pkgs, ... }:

let
  gameDirectory = "/home/xunil/dev/didacta_game/dist";

  kioskApplication = pkgs.writeShellScript "feed-me-kiosk-application" ''
    set -eu

    # Cage's "last" output mode enables one output. Rotate that output after
    # the Wayland socket exists, regardless of whether it is the laptop panel
    # during testing or the exhibition monitor in production.
    output="$(${pkgs.wlr-randr}/bin/wlr-randr --json \
      | ${pkgs.jq}/bin/jq -r '.[] | select(.enabled == true) | .name' \
      | ${pkgs.coreutils}/bin/head -n 1)"
    if [ -n "$output" ]; then
      ${pkgs.wlr-randr}/bin/wlr-randr --output "$output" --transform 90
    fi

    # Reuse the saved NetworkManager connection when available. The fallback
    # also makes first-time booth setup deterministic.
    ${pkgs.networkmanager}/bin/nmcli connection up FeedMeController >/dev/null 2>&1 \
      || ${pkgs.networkmanager}/bin/nmcli device wifi connect FeedMeController password feedme-board >/dev/null 2>&1 \
      || true

    if [ ! -f ${gameDirectory}/index.html ]; then
      echo "FEED ME production build missing: ${gameDirectory}/index.html" >&2
      exit 1
    fi

    ${pkgs.busybox}/bin/httpd -f -p 127.0.0.1:4173 -h ${gameDirectory} &
    server_pid=$!
    trap '${pkgs.coreutils}/bin/kill "$server_pid" 2>/dev/null || true' EXIT INT TERM

    ${pkgs.google-chrome}/bin/google-chrome-stable \
      --ozone-platform=wayland \
      --kiosk \
      --app=http://127.0.0.1:4173/ \
      --user-data-dir="$HOME/.local/share/feed-me-kiosk/chromium" \
      --password-store=basic \
      --no-first-run \
      --no-default-browser-check \
      --disable-session-crashed-bubble \
      --disable-infobars \
      --disable-translate \
      --overscroll-history-navigation=0
  '';

  kioskSession = pkgs.writeShellScript "feed-me-kiosk-session" ''
    exec ${pkgs.cage}/bin/cage -d -s -m last -- ${kioskApplication}
  '';

  sessionPackage = pkgs.runCommand "feed-me-kiosk-session" {
    passthru.providedSessions = [ "feed-me-kiosk" ];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/feed-me-kiosk.desktop <<EOF
    [Desktop Entry]
    Name=Feed Me Kiosk
    Comment=Run FEED ME fullscreen in a tear-free Wayland kiosk
    Exec=${kioskSession}
    Type=Application
    DesktopNames=FeedMeKiosk
    EOF
  '';
in
{
  services.displayManager.sessionPackages = [ sessionPackage ];

  # Useful for diagnostics from a TTY; the session itself refers to exact
  # store paths and does not depend on these being in PATH.
  environment.systemPackages = with pkgs; [
    cage
    wlr-randr
  ];
}
