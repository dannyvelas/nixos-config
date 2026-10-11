{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Apple EFI is picky; the removable path is the most reliable way to boot
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostName = "mbp";
  networking.networkmanager.enable = true;
  time.timeZone = "America/New_York";

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;

  programs.firefox.enable = true;

  # Keeps your fast SSH loop alive after the first reboot
  services.openssh.enable = true;
  services.avahi = { enable = true; nssmdns4 = true; publish = { enable = true; addresses = true; }; };

  users.users.dannyvelasquez = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };
  security.sudo.wheelNeedsPassword = false;

  services.mbpfan.enable = true;
  hardware.enableRedistributableFirmware = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
