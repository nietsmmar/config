{ config, pkgs, lib, ... }:

{
  programs.nm-applet.enable = true;
  networking.networkmanager.enable = true;
  # Local dnsmasq resolver so internet-limit can block domains at runtime
  # (by dropping rules into /etc/NetworkManager/dnsmasq.d/). VPN/captive-portal
  # DNS keeps working because NM feeds per-connection upstreams to dnsmasq.
  networking.networkmanager.dns = "dnsmasq";
  networking.modemmanager.enable = true;
  networking.modemmanager.fccUnlockScripts = [
    {
      id = "2c7c:030a";
      path = "${pkgs.modemmanager}/share/ModemManager/fcc-unlock.available.d/2c7c:030a";
    }
  ];

  systemd.services.ModemManager = {
    enable = lib.mkForce true;
    path = [ pkgs.libmbim ]; # required by fcc-unlock-script
    wantedBy = [ "multi-user.target" "network.target" ];
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  services.displayManager.defaultSession = "none+i3";

  services.xserver = {
    xkb.layout = "de";
    xkb.variant = "";
    enable = true;
    
    displayManager = {
        sessionCommands =
          ''
          ${pkgs.xorg.xmodmap}/bin/xmodmap $HOME/dev/config/xmodmap/xmodmap
          '';
    };

    windowManager.i3 = {
        enable = true;
        extraPackages = with pkgs; [
            dmenu
            i3status
            i3lock
        ];
    };
  };

  # Secret Service (keyring) so apps like the Nextcloud client can persist
  # their login token across reboots. Bare i3 starts no keyring daemon on its
  # own, so without this the client has nowhere to store credentials and prompts
  # for login on every boot. PAM unlocks the keyring with the login password at
  # the LightDM greeter, so it's transparent (no separate keyring prompt).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;

  console.keyMap = "de";

  programs.zsh.enable = true;
  users.users.xunil = {  
    isNormalUser = true;
    description = "xunil";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "scanner" "lp" "docker" "i2c" ];
  };

  
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment the following
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # auto garbage collect nix
  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  # Create a systemd user service for battery monitoring
  systemd.user.services.battery-monitor = {
    description = "Battery level monitor";
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "battery-monitor" ''
        while true; do
          battery_level=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/BAT0/capacity)
          battery_status=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/BAT0/status)
          
          if [ "$battery_level" -le 10 ] && [ "$battery_status" = "Discharging" ]; then
            ${pkgs.libnotify}/bin/notify-send -u critical "Battery Low" "Battery level is at ''${battery_level}%"
          fi
          
          sleep 60  # Check every minute
        done
      '';
      Restart = "always";
    };
    wantedBy = [ "default.target" ];
  };

  # ── internet-limit: time-based internet / distraction / Telegram control ────
  # Script + config live in the repo so config edits take effect without a
  # rebuild: scripts/internet-limit/{internet-limit.sh,config.sh}
  systemd.services.internet-limit = {
    description = "Apply internet-limit rules for the current time";
    path = [ pkgs.networkmanager pkgs.procps pkgs.coreutils pkgs.util-linux pkgs.iptables pkgs.bash ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /home/xunil/dev/config/scripts/internet-limit/internet-limit.sh enforce";
    };
  };
  systemd.timers.internet-limit = {
    description = "Run internet-limit enforcement every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "60s";
      AccuracySec = "1s";
    };
  };


  # printing
  services.printing.enable = true;
  services.ipp-usb.enable = true;

  hardware.printers = {
    ensurePrinters = [
      {
        name = "HP_ENVY_4520";
        location = "Home";
        deviceUri = "ipp://HP705A0F6C29F1.local:631/ipp/print";
        model = "everywhere";
      }
    ];
    ensureDefaultPrinter = "HP_ENVY_4520";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # scanner
  hardware = {
    sane = {
      enable = true;
      brscan5 = {
        enable = true;
      };
    };
  };

  # enable nix-ld to fix linker
  programs.nix-ld.enable = true;

  # qt dark-mode
  #qt = {
  #  enable = true;
  #  platformTheme = "gnome";
  #  style = "adwaita-dark";
  #};

  services.gvfs.enable = true; # mount, trash...
  services.tumbler.enable = true; # thumbnails support
  programs.dconf.enable = true;

  # Clipboard history — clipmenud daemon; browse/paste via `clipmenu` (dmenu).
  # Bound to $super+c in the i3 config.
  services.clipmenu.enable = true;

  # Automount USB drives. udisks2 is the backend; the udiskie frontend is
  # autostarted from the i3 config (`exec udiskie`) — there's no NixOS system
  # module for udiskie (that option only exists in home-manager).
  services.udisks2.enable = true;

  # i2c/DDC-CI access for controlling external monitor brightness (ddcutil).
  # Loads i2c-dev, creates the `i2c` group (xunil is a member above).
  hardware.i2c.enable = true;

  # required for flameshot (v14+) to access org.freedesktop.portal.Desktop for screen capture
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # fix gstreamer audio/video properties in nautilus
  environment.sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (with pkgs.gst_all_1; [
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ]);

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # make iphone mount
  services.usbmuxd.enable = true;

  # PC/SC smart card daemon — required for eGK card reader (Identiv SPR332 v2)
  services.pcscd.enable = true;

  # udev rule for Identiv SPR532 (04e6:e003) — grants pcscd access to the reader
  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="04e6", ATTRS{idProduct}=="e003", GROUP="pcscd", MODE="0660", TAG+="uaccess"
  '';

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
      # `internet-limit {status|pause [DUR]|resume}` — see scripts/internet-limit/
      (writeShellScriptBin "internet-limit" ''
        exec /home/xunil/dev/config/scripts/internet-limit/internet-limit.sh "$@"
      '')
      brightnessctl
      udiskie # USB automount frontend (autostarted from i3)
      xclip # clipboard access for ocr-region / color-picker scripts
      xcolor # screen colour picker (color-picker script)
      tesseract # OCR engine (ocr-region script; incl. eng+deu data)
      ddcutil # external monitor brightness over DDC/CI (monitor-brightness script)
      libmbim # mobile sim
      kdePackages.okular
      supabase-cli
      keepassxc
      wget
      lxappearance
      xorg.xmodmap
      libsForQt5.qt5ct
      adwaita-icon-theme
      adwaita-qt
      adwaita-qt6
      alsa-utils
      alsa-tools
      xorg.xprop
      zip
      dconf
      libimobiledevice
      imagemagick
      ffmpeg-full
      dunst
      libnotify
      ocrmypdf
      pdfgrep
      firefox
      git
      betterbird
      kitty
      zsh
      telegram-desktop
      gcc
      vscode
      spotify
      arandr
      fzf
      unzip
      fd
      eza
      bat
      google-chrome
      keepassxc
      nextcloud-client
      slack
      flameshot
      pavucontrol
      vlc
      signal-desktop
      playerctl
      inkscape
      nomacs
      jetbrains.pycharm-oss
      nautilus
      sushi # previewer for nautilus
      tinysparql # file indexer and search tool
      localsearch # metadata extractors for tracker
      ffmpegthumbnailer # video thumbnails nautilus
      gst_all_1.gst-libav # video thumbnails nautilus
      anki
      android-studio-flutter
      obs-studio
      tor-browser
      kdePackages.kdenlive
      xdotool
      simple-scan
      brscan5
      veracrypt
      openssl
      gnutar
      libreoffice
      filezilla
      gemini-cli
      xautolock
      redshift
      nodejs_24 # for npx supabase mcp
      obsidian
      kdePackages.kolourpaint
      postman
      claude-code
      stripe-cli
      tk-safe
      jq
      gedit
      mumble
      gamemode
  ];

  # qt
  qt.enable = true;
  qt.platformTheme = "qt5ct";

  # environment variables
  environment.sessionVariables = rec {
    QT_QPA_PLATFORM = "xcb";
    QT_QPA_PLATFORMTHEME="qt5ct";

    XDG_CACHE_HOME  = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME   = "$HOME/.local/share";
    XDG_STATE_HOME  = "$HOME/.local/state";

    #NIX_BUILD_SHELL = "zsh";

    # Not officially in the specification
    XDG_BIN_HOME    = "$HOME/.local/bin";
    
    ANDROID_HOME = "$HOME/dev/android/sdk";
    BROWSER = "/bin/google-chrome-stable";
    CHROME_EXECUTABLE = "$HOME/dev/config/scripts/google-chrome-unsafe.sh";
    CONFIG = "$HOME/dev/config";
    SCRIPTS = "$HOME/dev/config/scripts";
    PATH = "$HOME/dev/config/scripts";
  };

  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}
