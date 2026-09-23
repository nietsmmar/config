# Temporary hardware module for andreas-pc.
#
# Replace this entire file after booting the NixOS installer:
#   nixos-generate-config --root /mnt
#   cp /mnt/etc/nixos/hardware-configuration.nix \
#     /mnt/path/to/this/repo/hardware/andreas-pc.nix
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Evaluation-only placeholder; nixos-generate-config will provide the real
  # device, filesystem type, swap and initrd modules during installation.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
