{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2".device = "/dev/disk/by-uuid/cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2";

  # Use 6.12 LTS kernel — more stable than 6.18, avoids SLUB alloc_tagging bug
  # causing disk I/O stalls and hard freezes on LUKS-encrypted drives.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Prevent xe (newer Intel GPU driver) from loading alongside i915.
  # Both were loading for the same Alder Lake P iGPU, causing potential
  # interference during GPU power transitions and display pipeline failures.
  boot.blacklistedKernelModules = [ "xe" ];

  # Enable full SysRq so the system can be recovered without a hard reboot.
  # When frozen: Alt+SysRq+S (sync), +U (remount ro), +B (reboot).
  boot.kernel.sysctl."kernel.sysrq" = 1;

  boot.kernelParams = [
    # Disable i915 GuC GPU scheduler — known to cause hard lockups on Alder Lake P.
    # Falls back to the legacy submission path which is more stable.
    "i915.enable_guc=0"

    # Disable Panel Self Refresh — common cause of i915 display pipeline freezes
    # on Alder Lake P laptops after suspend/hibernate resume.
    "i915.enable_psr=0"

    # Disable display C-states — prevents GPU power transitions from disrupting
    # the DisplayPort MST link used for daisy-chained monitors. Tradeoff: slightly
    # higher idle power draw.
    "i915.enable_dc=0"

    # Enable NMI watchdog — fires even during a complete CPU lockup and prints
    # a stack trace to the kernel log, helping diagnose future freezes.
    "nmi_watchdog=1"
  ];

  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Enable = "Source,Sink,Media,Socket";
      Name = "Hello";
      ControllerMode = "dual";
      FastConnectable = "true";
      Experimental = "true";
      KernelExperimental = "true";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      mesa
    ];
  };
  services.xserver.videoDrivers = [ "modesetting" ];

  services.picom = { # Enable picom service
    enable = true;
    backend = "xrender"; # Changed to xrender for compatibility
    vSync = true; # Enable vsync to prevent tearing
    fade = false;
    shadow = false;
  };

  environment.systemPackages = with pkgs; [
    picom # Add picom for compositing
    vulkan-loader # Vulkan loader
    intel-compute-runtime # Intel Vulkan driver
    vulkan-tools # Vulkan diagnostic tools
    libva-utils # VA-API diagnostic tool
  ];

  environment.sessionVariables = {
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
  };

  # Reset GSM modem after resume from suspend to clear the device-id mismatch.
  # Waits up to 2 minutes for ModemManager to detect the modem naturally,
  # using mmcli -L to find any modem rather than assuming index 0.
  systemd.services.modem-resume-reset = {
    description = "Reset GSM modem after resume from suspend";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = 150;
      ExecStart = pkgs.writeShellScript "modem-reset" ''
        for i in $(seq 1 60); do
          sleep 2
          modem=$(${pkgs.modemmanager}/bin/mmcli -L 2>/dev/null \
            | grep -oE '/org/freedesktop/ModemManager1/Modem/[0-9]+' \
            | head -1)
          if [ -n "$modem" ]; then
            ${pkgs.modemmanager}/bin/mmcli -m "$modem" --reset
            exit 0
          fi
        done
        echo "modem not found after 120s" >&2
        exit 1
      '';
    };
  };

}
