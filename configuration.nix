{ config, lib, pkgs, inputs, ... }:
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
  programs.fish.enable = true;

  # waybar's default modules render icons from this glyph set; without it they show as tofu boxes
  # alacritty's font (../dotfiles/.config/alacritty/alacritty.toml) is "FiraMono Nerd Font"
  fonts.packages = [ pkgs.font-awesome pkgs.nerd-fonts.fira-mono ];

  environment.variables.EDITOR = "nvim"; # overrides NixOS's default of nano

  environment.systemPackages = with pkgs; [
    alacritty   # terminal
    bitwarden-desktop
    brightnessctl
    btop
    claude-code
    fzf         # fish shell integration, see ../dotfiles/.config/fish/config.fish
    gcc         # C compiler nvim-treesitter needs to compile parsers
    git
    gnumake     # handy for projects that use Makefiles
    jjui        # TUI for jujutsu
    jujutsu     # jj; fish shell completions, see ../dotfiles/.config/fish/config.fish
    neovim
    obsidian
    playerctl   # media key bindings in sway/config
    ripgrep     # rg
    sops        # edit/rotate secrets/secrets.yaml
    tmux
    waybar      # status bar
    wofi        # app launcher
    mako        # notifications
    tuigreet
    zoxide      # fish shell integration, see ../dotfiles/.config/fish/config.fish
  ] ++ (
    # LazyVim (../dotfiles/.config/nvim) uses Mason to install LSP servers,
    # formatters, linters and debuggers at runtime. That works on macOS but
    # not on NixOS: most Mason-downloaded binaries are generic Linux builds
    # that fail with "Could not start dynamically linked executable" here.
    # So on NixOS, Mason is disabled instead (../dotfiles/.config/nvim/lua/
    # plugins/nixos.lua, gated on /etc/NIXOS) and every tool it would have
    # installed is provided natively by Nix below.
    #
    # This list has to be kept in sync by hand with the LazyVim extras
    # enabled in ../dotfiles/.config/nvim/lazyvim.json -- if you enable a
    # new language extra there, its tools need to be added here too.
    with pkgs; [
      clang-tools              # clangd (C/C++ LSP)
      delve                    # Go debugger (dap.core + lang.go)
      gofumpt                  # Go formatter
      golangci-lint            # Go linter
      gopls                    # Go LSP
      gotools                  # goimports (Go formatter)
      lua-language-server      # Lua LSP
      nodejs                   # runs Copilot's bundled agent; also vtsls' runtime
      ocamlPackages.ocaml-lsp  # ocamllsp (OCaml LSP)
      pyright                  # Python LSP
      ruff                     # Python LSP/linter/formatter
      rust-analyzer            # Rust LSP (invoked directly by rustaceanvim)
      stylua                   # Lua formatter
      terraform-ls             # Terraform LSP
      tflint                   # Terraform linter
      tree-sitter              # CLI nvim-treesitter shells out to for parser builds
      vscode-langservers-extracted  # vscode-json-language-server (JSON LSP)
      vtsls                    # TypeScript/JavaScript LSP
      yaml-language-server     # YAML LSP
      go                       # Go toolchain itself (gopls/goimports/gofumpt all shell out to it)
    ]
  );

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
  home-manager.users.dannyvelasquez = { config, ... }: let
    dotfilesDir = "${config.home.homeDirectory}/RemoteGit/MyGithub/dotfiles";
    outOfStore = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${path}";
  in {
    imports = [ inputs.sops-nix.homeManagerModules.sops ];
    home.stateVersion = "26.05";

    # Master key for everything in secrets/secrets.yaml. Not managed by Nix:
    # on a new machine, pull it out of the "nixos sops age key" Bitwarden
    # note into this path before the first rebuild that needs a secret.
    sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    sops.defaultSopsFile = ./secrets/secrets.yaml;

    programs.git = {
      enable = true;
      settings.user = {
        name = "Daniel Velasquez";
        email = "42185968+dannyvelas@users.noreply.github.com";
      };
    };

    # Private keys are sops-managed (secrets/secrets.yaml), decrypted here on every activation
    sops.secrets."ssh/id_ed25519_github" = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
      mode = "0600";
    };
    sops.secrets."ssh/id_ed25519_vultr" = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_vultr";
      mode = "0600";
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        IdentityAgent = "\${XDG_RUNTIME_DIR}/ssh-agent";
        AddKeysToAgent = "yes";
      };
      settings."github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_github";
        IdentitiesOnly = "yes";
      };
      settings."park-spot.co" = {
        User = "admin";
        Port = 17031;
        IdentityFile = "~/.ssh/id_ed25519_vultr";
        IdentitiesOnly = "yes";
      };
    };

    services.ssh-agent.enable = true;

    xdg.configFile."sway/config".source = ./sway/config;
    xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;

    # Shared across machines; single source of truth lives in ../dotfiles,
    # these just symlink straight to the checkout so edits apply with no rebuild.
    home.file.".tmux.conf".source = outOfStore ".tmux.conf";
    xdg.configFile."nvim".source = outOfStore ".config/nvim";
    xdg.configFile."alacritty/alacritty.toml".source = outOfStore ".config/alacritty/alacritty.toml";
    xdg.configFile."fish".source = outOfStore ".config/fish";
  };

  services.mbpfan.enable = true;
  hardware.enableRedistributableFirmware = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
