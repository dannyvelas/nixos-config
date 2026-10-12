# nixos-config

NixOS config for `mbp`, a 2014 MacBook Pro: Sway, Alacritty, Bitwarden,
Firefox, Broadcom BCM4360 Wi-Fi, and a home-manager-managed git/SSH setup
for GitHub. Built from a flake (`flake.nix` + `flake.lock`), so every
package version is pinned and reproducible — no `nix-channel` involved
anywhere.

tmux, Neovim, Alacritty, and fish configs aren't declared here — they're
symlinked in from a separate [`dotfiles`](https://github.com/dannyvelas/dotfiles)
repo shared across machines. See "Shared dotfiles" below.

**Setting this up from scratch** (USB installer → a fully working desktop)?
See [How to install NixOS with Sway and Broadcom Wi-Fi on a 2014 MacBook
Pro](https://github.com/dannyvelas/notes/blob/main/vault/how-to-install-nixos-with-sway-and-broadcom-wifi-on-a-2014-macbook-pro.md)
(private `notes` repo) — that's the complete step-by-step, including
cloning and applying this repo. Nothing here duplicates it.

This README covers what you need once that's done: how to rebuild, and
how to fix the handful of things that have already gone wrong once.

## Rebuilding after a change

`/etc/nixos` is a plain directory, **not a symlink** into this repo —
deploying a change means copying the repo into it, then rebuilding with
the flake:

```
sudo rsync -a --delete ~/RemoteGit/MyGithub/nixos-config/ /etc/nixos/ --exclude='.git'
sudo chown -R root:root /etc/nixos/
cd /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#mbp
```

Plain `nixos-rebuild switch` with no `--flake` flag is never correct here
— it relies on nix-channel machinery this config doesn't use.

If the rebuild touched `flake.lock` (e.g. the very first run, or after
bumping an input), copy it back into the repo before committing:

```
cp /etc/nixos/flake.lock ~/RemoteGit/MyGithub/nixos-config/flake.lock
```

## GitHub SSH access

Git identity and the `Host github.com` / `IdentityAgent` SSH config are
declared under `home-manager.users.dannyvelasquez` in `configuration.nix`
and applied automatically by the rebuild above. The agent itself doesn't
persist loaded keys across reboots, so after every reboot:

```
ssh-add ~/.ssh/id_ed25519_github
```

## Shared dotfiles

tmux, Neovim, Alacritty, and fish configs live in the separate
[`dotfiles`](https://github.com/dannyvelas/dotfiles) repo, since they're
shared across machines (not just this one) and would drift if duplicated
here. `home-manager.users.dannyvelasquez` in `configuration.nix` points
`home.file`/`xdg.configFile` entries at that repo via
`mkOutOfStoreSymlink`, hardcoded to expect a clone at
`~/RemoteGit/MyGithub/dotfiles`. That makes them real out-of-store
symlinks rather than files copied into the Nix store, so editing a config
in `dotfiles` takes effect immediately — no rebuild needed. It also means
the rebuild never checks the clone exists: see the troubleshooting entry
below if a tool behaves as if unconfigured.

sway and waybar configs, by contrast, are declared directly in this repo
(`./sway/config`, `./waybar/config.jsonc`) because they're specific to
this machine — there's nothing to deduplicate.

## Troubleshooting

- **Build error: `'<pkg>' has been renamed to/replaced by '<new-pkg>'`** —
  nixpkgs renamed a package between releases (this has already happened
  twice on this config: `bitwarden` → `bitwarden-desktop`,
  `greetd.tuigreet` → `tuigreet`). Swap in the new name the error gives
  you in `configuration.nix` and rebuild again.
- **`nixos-rebuild` complains about `nixpkgs/nixos` not being in the Nix
  search path, or `$NIX_PATH`** — something is invoking the non-flake
  `nixos-rebuild switch` (no `--flake` flag), or a leftover `nix-channel`
  is being touched. Always use `sudo nixos-rebuild switch --flake /etc/nixos#mbp`.
- **A file home-manager should manage (e.g. `~/.config/git/config`) looks
  unmanaged / isn't a symlink into `/nix/store/...`** — there's probably an
  older unmanaged file still sitting at a legacy path shadowing it (git
  reads `~/.gitconfig` *after* `~/.config/git/config`, so a stale
  `~/.gitconfig` wins). Check with `readlink -f <path>`; if it doesn't
  point into `/nix/store`, remove the stale file and rebuild — home-manager
  is also configured to back up (`.backup` suffix) rather than silently
  overwrite any unmanaged file it finds in its way.
- **GitHub SSH stopped working after a reboot** — see "GitHub SSH access"
  above.
- **`nvim`/`tmux`/`fish`/`alacritty` behave as if unconfigured, with no
  error from the rebuild** — the `dotfiles` clone is either missing or not
  at `~/RemoteGit/MyGithub/dotfiles` exactly, so the out-of-store symlink
  is dangling. Check with `readlink -f ~/.config/nvim` (etc.); if it
  doesn't resolve into that clone, fix the clone's location rather than
  editing `configuration.nix`. See "Shared dotfiles" above.
- For anything about partitioning, the Broadcom driver, the password hash
  file, or the install itself, see the "If something goes wrong" section
  of the [install note](https://github.com/dannyvelas/notes/blob/main/vault/how-to-install-nixos-with-sway-and-broadcom-wifi-on-a-2014-macbook-pro.md).
