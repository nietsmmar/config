{ pkgs, ... }:

{
  # This host intentionally does not import ../configuration.nix: that module
  # contains xunil's user, i3 setup, development tools and personal services.

  # This computer boots in legacy BIOS mode. Install GRUB only on the dedicated
  # NixOS SSD, addressed by its stable hardware ID so reconnecting the other
  # disks cannot cause a future rebuild to overwrite the wrong drive.
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-FIKWOT_FX815_512GB_26030642612020488";
    useOSProber = true;
  };

  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "de_DE.UTF-8";
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
  console.keyMap = "de";

  services.xserver = {
    enable = true;
    xkb.layout = "de";
    displayManager.lightdm.enable = true;
    desktopManager.cinnamon.enable = true;
  };
  services.displayManager.defaultSession = "cinnamon";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  services.printing.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.fwupd.enable = true;
  services.pcscd.enable = true;

  programs.firefox.enable = true;
  programs.dconf.enable = true;

  # Use Nautilus as the file manager.
  xdg.mime.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    "application/x-gnome-saved-search" = [ "org.gnome.Nautilus.desktop" ];
  };

  users.users.andreas = {
    isNormalUser = true;
    description = "Andreas";
    extraGroups = [ "networkmanager" "wheel" "scanner" "lp" ];
  };

  environment.systemPackages = with pkgs; [
    signal-desktop
    telegram-desktop
    libreoffice
    thunderbird
    google-chrome
    vlc
    flameshot
    masterpdfeditor4
    pdfarranger
    darktable
    simple-scan
    evince
    dropbox
    nautilus
    qsync
    ausweisapp
    tk-safe

    # Google Calendar has no native Linux client. This opens it in a dedicated
    # Chrome window and gives it a normal application-menu entry.
    (makeDesktopItem {
      name = "google-calendar";
      desktopName = "Google Calendar";
      comment = "Open Google Calendar";
      icon = "x-office-calendar";
      exec = "${google-chrome}/bin/google-chrome-stable --app=https://calendar.google.com/";
      categories = [ "Office" "Calendar" ];
    })

    # Gmail also has no native Linux client.
    (makeDesktopItem {
      name = "gmail";
      desktopName = "Gmail";
      comment = "Open Gmail";
      icon = "mail-message-new";
      exec = "${google-chrome}/bin/google-chrome-stable --app=https://mail.google.com/";
      categories = [ "Network" "Email" ];
    })
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  nixpkgs.config.allowUnfree = true;

  # Keep this at the release used for the first installation of this host.
  system.stateVersion = "26.05";
}
