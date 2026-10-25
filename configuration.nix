{ config, lib, pkgs, ... }:
let
  # Official Slack CLI (slack login/run/deploy, for building Slack apps) isn't in
  # nixpkgs -- only "slack-cli" there is rockymadden/slack-cli, an unrelated legacy-
  # token tool that also claims the `slack` binary name. Pin Slack's own release
  # tarball by exact version + hash instead of their `curl | bash` installer, so the
  # build stays reproducible. Bump the version and sha256 by hand to upgrade:
  # https://docs.slack.dev/tools/metadata.json has the latest version number.
  slackCliOfficial = pkgs.stdenv.mkDerivation {
    pname = "slack-cli";
    version = "4.10.0";
    src = pkgs.fetchurl {
      url = "https://downloads.slack-edge.com/slack-cli/slack_cli_4.10.0_linux_amd64.tar.gz";
      sha256 = "9772b17f70c4ec522ea6ae25545220dfe17d6afb5babe28fa1cd55a24b2abffa";
    };
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      install -Dm755 bin/slack $out/bin/slack
      install -Dm444 LICENSE $out/share/licenses/slack-cli/LICENSE
    '';
  };
in
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
    extraPackages = with pkgs; [ brightnessctl grim pulseaudio slurp swayidle swaylock ];
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

  environment.systemPackages = with pkgs; [
    alacritty   # terminal
    bitwarden-desktop
    brightnessctl
    btop
    bws         # Bitwarden Secrets Manager CLI
    claude-code
    kdePackages.dolphin  # file manager; `open .` opens it, see ../dotfiles/.config/fish/functions/open.fish
    fzf         # fish shell integration, see ../dotfiles/.config/fish/config.fish
    gcc         # C compiler nvim-treesitter needs to compile parsers
    gh          # GitHub CLI
    git
    gnumake     # handy for projects that use Makefiles
    imv         # Wayland-native image viewer
    jjui        # TUI for jujutsu
    jq
    jujutsu     # jj; fish shell completions, see ../dotfiles/.config/fish/config.fish
    kamal       # deploy backend-parkspot, see https://kamal-deploy.org/
    mpv         # video player
    neovim
    obsidian
    openssl
    playerctl   # media key bindings in sway/config
    rclone      # Google Drive access; no official Linux client exists
    ripgrep     # rg
    slackCliOfficial  # official Slack CLI, see `let` block at top for why
    tmux
    vultr-cli   # official Vultr CLI
    waybar      # status bar
    wf-recorder # screen recording; see sway/config for keybind
    wl-clipboard # wl-copy/wl-paste; Wayland equivalent of macOS pbcopy/pbpaste
    wofi        # app launcher
    mako        # notifications
    tuigreet
    yq-go       # YAML processor (mikefarah's, not the Python jq-wrapper yq)
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
      terraform                # Terraform CLI (terraform-ls shells out to this for provider schemas)
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

  virtualisation.docker.enable = true;

  users.users.dannyvelasquez = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
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
  home-manager.users.dannyvelasquez = { config, pkgs, ... }: let
    dotfilesDir = "${config.home.homeDirectory}/RemoteGit/MyGithub/dotfiles";
    outOfStore = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${path}";
  in {
    home.stateVersion = "26.05";

    # SSH private keys are NOT managed by Nix. Each key lives on disk, scoped
    # to this one computer and one resource, passphrase-protected, with the
    # passphrase (not the key) kept in Bitwarden. See the "how I manage my
    # SSH keys" note and the SSH section of the bootstrap playbook.
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
    xdg.configFile."git/config".source = outOfStore ".config/git/config";

    # Keeps ~/GoogleDrive mounted across reboots so `rclone mount` never has
    # to be run by hand. Type=notify relies on rclone's own sd_notify call,
    # so dependents see a fully-populated mount, not a race.
    systemd.user.services.rclone-gdrive = {
      Unit = {
        Description = "Mount Google Drive via rclone";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "notify";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${config.home.homeDirectory}/GoogleDrive";
        ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive: ${config.home.homeDirectory}/GoogleDrive --vfs-cache-mode writes --config ${config.home.homeDirectory}/.config/rclone/rclone.conf";
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

  # logind's default (HandlePowerKey=poweroff) shuts the machine down on a
  # single press/release, so waking it from sleep -- or a finger slip --
  # triggers an unwanted shutdown. Flip it to match real macOS: a short press
  # does nothing, only a held press powers off.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };

  services.mbpfan.enable = true;
  hardware.enableRedistributableFirmware = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
