{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2".device = "/dev/disk/by-uuid/cdc0ad6a-bcc0-4a3c-ab30-a7cbf43cb0a2";
}
