{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2".device = "/dev/disk/by-uuid/cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2";

  # Pass TRIM/discard through the LUKS layer so the weekly fstrim.timer actually
  # reaches the SSD (dm-crypt blocks discards by default). Minor security
  # tradeoff: reveals which blocks are in use. Applied to both LUKS containers
  # (the second is declared in the generated hardware/laptop.nix).
  boot.initrd.luks.devices."luks-cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2".allowDiscards = true;
  boot.initrd.luks.devices."luks-e1292fc1-2b30-4470-a79e-3abaf76efbd2".allowDiscards = true;

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

  services.fwupd.enable = true;

  # ── TLP: power management (battery saving + charge threshold) ───────────────
  # ThinkPad (i7-1255U, intel_pstate). Aggressive power-save on battery to slow
  # drain when unplugged; charge cap at 80% to preserve battery lifespan while
  # docked. Charge thresholds use the kernel's native sysfs (natacpi) support.
  # Laptop-only: on the desktop the `powersave` governor cripples the CPU.
  services.tlp = {
    enable = true;
    settings = {
      # Charge thresholds — stop at 80% to reduce wear when permanently docked.
      # To force a one-off full charge: `sudo tlp fullcharge`.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # CPU: let it ramp on AC, favour power saving on battery.
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;               # no turbo on battery — big drain saver
      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      # Platform / thermal profile.
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Runtime power management for PCIe/USB devices on battery.
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # WiFi power saving on battery.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
    };
  };

  # NOTE: thermald is intentionally NOT enabled. This ThinkPad exposes DYTC
  # (dytc_lapmode) — the firmware handles adaptive thermal management itself and
  # thermald refuses to run alongside it. That native mechanism is already
  # driven via TLP's PLATFORM_PROFILE_ON_AC/BAT settings.

  # Don't suspend when the lid is closed while docked or driving external
  # displays (this is already the systemd default; set explicitly for clarity).
  services.logind.lidSwitchDocked = "ignore";

  # Cleanly hibernate before the battery dies (session survives to disk and
  # resumes on next power-on). Hibernate/resume is already working on this
  # machine. Fires at 5% based on percentage rather than time-remaining.
  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
  };

  # Blue-light reduction in the evenings (Karlsruhe coords). Previously started
  # from the i3 config via `exec redshift -l ...`; managed here instead so it's
  # a proper service — remember to drop the i3 exec line.
  services.redshift.enable = true;
  location = {
    provider = "manual";
    latitude = 49.0047222;
    longitude = 8.3858333;
  };

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

  # autorandr: auto-apply saved display layouts on dock/undock (monitor hotplug).
  # After a rebuild, save profiles once with the desired layout applied, e.g.:
  #   autorandr --save docked      (with external monitors connected)
  #   autorandr --save mobile      (laptop screen only)
  # It then switches automatically when you dock/undock.
  services.autorandr.enable = true;

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
