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

  # BCM4360 Wi-Fi needs the proprietary wl driver (unfree and flagged insecure)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "broadcom-sta-6.30.223.271-59-6.18.55" ];
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [ "b43" "bcma" "ssb" "brcmsmac" "brcmfmac" ];

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
    hashedPassword = "$6$QT2EEBX0LT.gwkc7$Q.wgXdnERpfy/SxqS01bVqX.WxzTFlEgp6XA9kbL7x5/aQityr90yb7YEc0QYQH9nBZgCJD1XaCDtNst399Kq0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINgCvIlrPS3ePhD/8nEQIUOssl75B+215b3HEcCkEnjb dannyvelasquez@Daniels-MacBook-Pro.local"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.mbpfan.enable = true;
  hardware.enableRedistributableFirmware = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
