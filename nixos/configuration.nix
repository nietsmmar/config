# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
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

  # Configure keymap in X11
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

  # Configure console keymap
  console.keyMap = "de";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  programs.zsh.enable = true;
  users.users.xunil = {  
    isNormalUser = true;
    description = "xunil";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "scanner" "lp" ];
    packages = with pkgs; [
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
        tuxguitar
        baobab
        calibre
        openssl
        gnutar
        libreoffice
    ];
  };

  # support flakes
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

  # sound support
  # hardware.pulseaudio.enable = true;

  # noisetorch (nosie cancelling for mic)
  programs.noisetorch.enable = true;

  # enable nix-ld to fix linker
  programs.nix-ld.enable = true;

  # steam 
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

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

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
	  # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Thunar file manager
  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  programs.thunar.plugins = with pkgs.xfce; [
       thunar-archive-plugin
       thunar-volman
  ];
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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
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

    DJANGO_DEBUG = "True"; #probably can remove now

    # Not officially in the specification
    XDG_BIN_HOME    = "$HOME/.local/bin";
    
    ANDROID_HOME = "$HOME/dev/android/sdk";
    BROWSER = "/bin/google-chrome-stable";
    CHROME_EXECUTABLE = "$HOME/dev/scripts/google-chrome-unsafe.sh";
    CONFIG = "$HOME/dev/config";
    SCRIPTS = "$HOME/dev/scripts";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}