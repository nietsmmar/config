{ config, pkgs, lib, ... }:

{
  networking.networkmanager.enable = true;

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

  console.keyMap = "de";

  programs.zsh.enable = true;
  users.users.xunil = {  
    isNormalUser = true;
    description = "xunil";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "scanner" "lp" ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # printing
  services.printing.enable = true;
  services.ipp-usb.enable=true; #usb

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

  # graphics
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # rocm-opencl-icd
      # rocm-opencl-runtime
    ];
  };

  # qt dark-mode
  #qt = {
  #  enable = true;
  #  platformTheme = "gnome";
  #  style = "adwaita-dark";
  #};

  services.gvfs.enable = true; # mount, trash...
  services.tumbler.enable = true; # thumbnails support

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

  environment.systemPackages = with pkgs; [
      wget
      lxappearance
      xorg.xmodmap
      libsForQt5.qt5ct
      adwaita-qt
      adwaita-qt6
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
        thunderbird
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
        # okular
        jetbrains.pycharm-community
        nautilus
        sushi
        anki
        sigil
        obs-studio
        tor-browser
        kdePackages.kdenlive
        xdotool
        simple-scan
        brscan5
        veracrypt
        baobab
        calibre
        openssl
        gnutar
        libreoffice
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

    NIX_BUILD_SHELL = "zsh"; # not working now with zsh

    # Not officially in the specification
    XDG_BIN_HOME    = "$HOME/.local/bin";
    
    ANDROID_HOME = "$HOME/dev/android/sdk";
    BROWSER = "/bin/google-chrome-stable";
    CHROME_EXECUTABLE = "$HOME/dev/scripts/google-chrome-unsafe.sh";
    CONFIG = "$HOME/dev/config";
    SCRIPTS = "$HOME/dev/scripts";
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
