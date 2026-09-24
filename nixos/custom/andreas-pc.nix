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

  # Internal data drives. Mount by filesystem UUID so device-name changes do
  # not affect them, and keep boot working if a drive is temporarily absent.
  fileSystems."/mnt/foto-filme-2tb" = {
    device = "/dev/disk/by-uuid/24BF8D08326CF936";
    fsType = "ntfs3";
    options = [
      "nofail"
      "x-systemd.device-timeout=30s"
      "uid=1000"
      "gid=100"
      "umask=0022"
      "x-gvfs-show"
      "x-gvfs-name=FOTO_FILME_2TB"
    ];
  };

  fileSystems."/mnt/daten-1tb" = {
    device = "/dev/disk/by-uuid/5B8E-31B2";
    fsType = "vfat";
    options = [
      "nofail"
      "x-systemd.device-timeout=30s"
      "uid=1000"
      "gid=100"
      "umask=0022"
      "iocharset=utf8"
      "x-gvfs-show"
      "x-gvfs-name=DATEN_1TB"
    ];
  };

  fileSystems."/mnt/windows-ssd" = {
    device = "/dev/disk/by-uuid/EA5878375878049B";
    fsType = "ntfs3";
    options = [
      "nofail"
      "x-systemd.device-timeout=30s"
      "uid=1000"
      "gid=100"
      "umask=0022"
      "x-gvfs-show"
      "x-gvfs-name=WINDOWS_SSD"
    ];
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

  programs.zsh.enable = true;

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

  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "HP_DeskJet_F4280";
        location = "Home";
        deviceUri = "usb://HP/Deskjet%20F4200%20series";
        model = "drv:///hp/hpcups.drv/hp-deskjet_f4200_series.ppd";
      }
    ];
    ensureDefaultPrinter = "HP_DeskJet_F4280";
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.hplip ];
    drivers.scanSnap.enable = true;
  };

  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.fwupd.enable = true;
  services.pcscd.enable = true;

  # Grant pcscd access to the Identiv SPR532 USB smart-card reader.
  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="04e6", ATTRS{idProduct}=="e003", GROUP="pcscd", MODE="0660", TAG+="uaccess"
  '';

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
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "scanner" "lp" ];
  };

  environment.systemPackages = with pkgs; [
    # New packages are inserted below this line by scripts/add-andreas-software.sh.
    # ANDREAS_SOFTWARE_MARKER
    signal-desktop
    telegram-desktop
    libreoffice
    thunderbird
    google-chrome
    vlc
    rhythmbox
    flameshot
    masterpdfeditor4
    pdfarranger
    darktable
    simple-scan
    evince
    kdePackages.okular
    dropbox
    nautilus
    qsync
    ausweisapp
    tk-safe
    git
    codex
    libnotify # provides notify-send for the OCR script
    ocrmypdf
    tesseract
    kitty
    zsh
    fzf
    fd
    bat
    kdePackages.kdenlive

    # Open Google Calendar in a regular Chrome tab from the application menu.
    (makeDesktopItem {
      name = "google-calendar";
      desktopName = "Google Calendar";
      comment = "Open Google Calendar";
      icon = "x-office-calendar";
      exec = "${google-chrome}/bin/google-chrome-stable https://calendar.google.com/";
      categories = [ "Office" "Calendar" ];
    })

    # Open Gmail in a regular Chrome tab from the application menu.
    (makeDesktopItem {
      name = "gmail";
      desktopName = "Gmail";
      comment = "Open Gmail";
      icon = "mail-message-new";
      exec = "${google-chrome}/bin/google-chrome-stable https://mail.google.com/";
      categories = [ "Network" "Email" ];
    })
  ];

  # Start Qsync when Andreas logs into Cinnamon. The internal data drives are
  # mounted during boot, before the graphical login session starts.
  environment.etc."xdg/autostart/QNAPQsyncClient.desktop".source =
    "${pkgs.qsync}/share/applications/QNAPQsyncClient.desktop";

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
