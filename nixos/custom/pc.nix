{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-Samsung_SSD_840_EVO_120GB_S1D5NSAFB35914V";
  boot.loader.grub.useOSProber = true;

  # Pin to 6.12 LTS kernel — 6.18 causes boot hang with NVIDIA drivers
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidiaPackages.legacy_580 ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # CPU frequency governor. Desktop is always on AC, so scale up on demand:
  # `schedutil` ramps to full clock under load and idles down when not. Set
  # explicitly because the intel_pstate driver runs in passive mode here, where
  # the `powersave` governor would otherwise pin every core to its minimum.
  powerManagement.cpuFreqGovernor = "schedutil";

  # noisetorch (nosie cancelling for mic)
  programs.noisetorch.enable = true;

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

    # GTX 1050 Ti dropped from 595.x+ drivers, use legacy_580
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  # graphics
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
