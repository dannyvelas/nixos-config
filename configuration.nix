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

  # F1/F2 etc. send media functions directly (fkeyslast), matching macOS; hold Fn for literal F-keys
  boot.extraModprobeConfig = ''
    options hid_apple fnmode=1
  '';

  networking.hostName = "mbp";
  networking.networkmanager.enable = true;
  time.timeZone = "America/New_York";

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # Default extraPackages includes foot and wmenu; alacritty/wofi are used instead
    extraPackages = with pkgs; [ brightnessctl grim pulseaudio swayidle swaylock ];
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
      user = "greeter";
    };
  };
  programs.firefox.enable = true;

  # waybar's default modules render icons from this glyph set; without it they show as tofu boxes
  fonts.packages = [ pkgs.font-awesome ];

  environment.systemPackages = with pkgs; [
    alacritty   # terminal
    bitwarden-desktop
    brightnessctl
    claude-code
    git
    neovim
    waybar      # status bar
    wofi        # app launcher
    mako        # notifications
    tuigreet
  ];

  # Keeps your fast SSH loop alive after the first reboot
  services.openssh.enable = true;
  services.avahi = { enable = true; nssmdns4 = true; publish = { enable = true; addresses = true; }; };

  users.users.dannyvelasquez = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPasswordFile = "/etc/secrets/dannyvelasquez.hash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINgCvIlrPS3ePhD/8nEQIUOssl75B+215b3HEcCkEnjb dannyvelasquez@Daniels-MacBook-Pro.local"
    ];
  };
  # Rebuild /etc/shadow from the config each switch, so the hash file stays the source of truth
  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;

  # home-manager-managed dotfiles for git/ssh; existing unmanaged files get a .backup suffix
  home-manager.backupFileExtension = "backup";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.dannyvelasquez = { ... }: {
    home.stateVersion = "26.05";

    programs.git = {
      enable = true;
      settings.user = {
        name = "Daniel Velasquez";
        email = "42185968+dannyvelas@users.noreply.github.com";
      };
    };

    # SSH key itself is generated separately with ssh-keygen (not something to put in the nix store)
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*".IdentityAgent = "\${XDG_RUNTIME_DIR}/ssh-agent";
      settings."github.com" = {
        HostName = "github.com";
        IdentityFile = "~/.ssh/id_ed25519_github";
        IdentitiesOnly = "yes";
      };
    };

    services.ssh-agent.enable = true;

    xdg.configFile."sway/config".source = ./sway/config;
    xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;
  };

  services.mbpfan.enable = true;
  hardware.enableRedistributableFirmware = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
