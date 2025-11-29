{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2".device = "/dev/disk/by-uuid/cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2";

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
      mesa.drivers
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

}
