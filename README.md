# nixos-config

NixOS config for `mbp`, a 2014 MacBook Pro. This README is the runbook for
going from a blank laptop and an installer USB stick to the exact desktop
this machine currently runs: Sway, Alacritty, Bitwarden, Firefox, and a
home-manager-managed git/SSH setup for GitHub — without having to remember
any of it.

It's split into two documents on purpose:

- **[How to install NixOS with KDE Plasma and Broadcom Wi-Fi on a 2014
  MacBook Pro](https://github.com/dannyvelas/notes/blob/main/vault/how-to-install-nixos-with-kde-plasma-and-broadcom-wifi-on-a-2014-macbook-pro.md)**
  (private `notes` repo) — the install mechanics: partitioning, the
  Broadcom `wl` driver, the password-hash-file dance, driving the whole
  install over SSH from a second computer. None of that is NixOS-release-
  or desktop-specific, so it isn't repeated here.
- **This README** — everything downstream of a bare NixOS boot: getting
  *this* repo onto the machine, the flake-based rebuild workflow, and the
  GitHub SSH setup. It also calls out the two places where that other note
  is now stale (see the callout in Phase 1).

## What you end up with

- Sway (via `greetd`/`tuigreet` as the login screen, not a graphical DM)
- Alacritty and foot as terminals, waybar/wofi/mako for bar/launcher/notifications
- Firefox, Bitwarden desktop app, Claude Code, git, neovim
- Broadcom BCM4360 Wi-Fi working via the proprietary `wl` driver
- The whole system built from a flake (`flake.nix` + `flake.lock`), so
  every package version is pinned and reproducible — no `nix-channel`
  involved anywhere
- git identity and SSH client config managed by home-manager, with a
  dedicated SSH key for pushing/pulling over SSH to GitHub

## Phase 1 — bare NixOS, Wi-Fi, your user, SSH access

Follow the [install note](https://github.com/dannyvelas/notes/blob/main/vault/how-to-install-nixos-with-kde-plasma-and-broadcom-wifi-on-a-2014-macbook-pro.md)
steps 1 through 8 as written (USB installer, boot, partition/format/mount,
`nixos-generate-config`, finding the exact Broadcom package name, grabbing
your SSH public key).

At its **Step 9** ("write `configuration.nix`"), ignore the snippet shown
there — it installs KDE Plasma + SDDM, but this machine runs **Sway** via
`greetd`/`tuigreet` instead. Use this repo's `configuration.nix` (clone it
on computer A if you haven't already: `git clone
https://github.com/dannyvelas/nixos-config.git`), with one temporary
change: **comment out or delete the `home-manager.backupFileExtension` /
`home-manager.useGlobalPkgs` / `home-manager.useUserPackages` /
`home-manager.users.dannyvelasquez` block.** Those options only exist
because `flake.nix` imports the home-manager module — on a from-scratch
install there's no running system yet to do that flake-based rebuild, so
evaluating `configuration.nix` by itself (which is exactly what the note's
Step 10 dry-run check and `nixos-install` in Step 12 do) would fail on an
unrecognized option. You'll bring that block back in Phase 2, right after
first boot, by cloning the full repo (unmodified) onto the running system
and rebuilding with the flake, which does know about home-manager.

Don't commit that temporary edit — just revert it locally
(`git checkout -- configuration.nix`) once you've copied the stripped file
to computer B in the note's Step 10.

Then continue the note exactly as written through:

- Step 10 (copy + dry-run check) — using your stripped `configuration.nix`
- Step 11 (password hash file)
- Step 12 (`nixos-install`)
- Step 13 (first boot)

Skip its Step 14 (verification) — that checks for Plasma/SDDM. Use Phase 4
of this README instead.

## Phase 2 — get this repo running on the machine

From here on, everything happens over SSH from your other computer (or
directly on the laptop once it has a terminal), on the now-booted,
bare-bones system from Phase 1.

1. Clone this repo (public, no auth needed) onto the new machine, with the
   `home-manager.*` block intact this time:

   ```
   git clone https://github.com/dannyvelas/nixos-config.git ~/RemoteGit/MyGithub/nixos-config
   ```

2. **Regenerate the hardware file for this machine** — `hardware-configuration.nix`
   encodes disk UUIDs and is specific to the exact install, not reusable
   as-is from git history. (If you already copied the one from the note's
   Step 6 into the cloned repo, this is a no-op.)

   ```
   sudo nixos-generate-config --show-hardware-config > ~/RemoteGit/MyGithub/nixos-config/hardware-configuration.nix
   ```

3. `/etc/nixos` is a plain directory, **not a symlink** into the repo —
   deploying a change means copying the repo into it:

   ```
   sudo rsync -a --delete ~/RemoteGit/MyGithub/nixos-config/ /etc/nixos/ --exclude='.git'
   sudo chown -R root:root /etc/nixos/
   ```

4. Rebuild, using the flake this time (this is the only command that
   should ever be used from here on — plain `nixos-rebuild switch` with no
   `--flake` flag relies on nix-channel machinery this config doesn't use):

   ```
   sudo nixos-rebuild switch --flake /etc/nixos#mbp
   ```

   This also writes `/etc/nixos/flake.lock` if it didn't already exist.
   Copy it back into the repo so the pin is committed:

   ```
   cp /etc/nixos/flake.lock ~/RemoteGit/MyGithub/nixos-config/flake.lock
   ```

5. Reboot. You should land on the `tuigreet` login screen, then a Sway
   session with waybar/mako running, and home-manager now managing your
   git/SSH config.

## Phase 3 — SSH access to GitHub (push/clone over SSH)

The login key from Phase 1 (in `openssh.authorizedKeys.keys`) is only for
*incoming* SSH to this machine. For *outgoing* git over SSH to GitHub, this
repo's home-manager config expects a separate, dedicated keypair at
`~/.ssh/id_ed25519_github`.

1. Generate it (skip if it already exists — don't overwrite a key that's
   already registered on GitHub):

   ```
   ssh-keygen -t ed25519 -C "<your email>" -f ~/.ssh/id_ed25519_github -N ""
   ```

2. In a browser, go to <https://github.com/settings/ssh/new> and paste the
   contents of `~/.ssh/id_ed25519_github.pub`.

3. Load the key into the running agent (home-manager's `services.ssh-agent`
   starts the agent itself, but doesn't persist loaded identities across
   reboots — this step is needed again after every reboot):

   ```
   ssh-add ~/.ssh/id_ed25519_github
   ```

4. Verify:

   ```
   ssh -T git@github.com
   ```

   should greet you by GitHub username.

Your git identity (`user.name`/`user.email`) and the `Host github.com` /
`IdentityAgent` entries in `~/.ssh/config` are declared in this repo's
`configuration.nix` under `home-manager.users.dannyvelasquez` — they get
applied automatically by the rebuild in Phase 2, no manual git config
needed.

## Phase 4 — verify everything

```
hostname                                   # mbp
lsmod | grep -E "^wl"                      # broadcom driver loaded
nmcli dev wifi list                        # wifi visible
swaymsg -t get_outputs                     # sway session is live
pgrep -x waybar mako                       # bar + notifications running
which alacritty foot bitwarden-desktop firefox claude git nvim
systemctl --user is-active ssh-agent.service
systemctl is-active home-manager-dannyvelasquez.service
ssh-add -l                                 # github key loaded (after step 3 above)
ssh -T git@github.com                      # greets you by username
cat ~/.config/git/config                   # home-manager-managed git identity
nixos-version
```

## Day-2 workflow — making further changes

1. Edit files in the cloned repo (not `/etc/nixos` directly).
2. Sync and rebuild:
   ```
   sudo rsync -a --delete ~/RemoteGit/MyGithub/nixos-config/ /etc/nixos/ --exclude='.git'
   sudo chown -R root:root /etc/nixos/
   cd /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#mbp
   ```
3. If the rebuild touched `flake.lock`, copy it back into the repo (step 4
   of Phase 2) before committing.
4. Commit and push from the repo as usual.

## Troubleshooting

- **Build error: `'<pkg>' has been renamed to/replaced by '<new-pkg>'`** —
  nixpkgs renamed a package between releases (this has already happened
  twice on this config: `bitwarden` → `bitwarden-desktop`,
  `greetd.tuigreet` → `tuigreet`). Swap in the new name the error gives
  you in `configuration.nix` and rebuild again.
- **`nixos-rebuild` complains about `nixpkgs/nixos` not being in the Nix
  search path, or `$NIX_PATH`** — something is invoking the non-flake
  `nixos-rebuild switch` (no `--flake` flag), or a leftover `nix-channel`
  is being touched. This config doesn't use channels at all; always use
  `sudo nixos-rebuild switch --flake /etc/nixos#mbp`.
- **A file home-manager should manage (e.g. `~/.config/git/config`) looks
  unmanaged / isn't a symlink into `/nix/store/...`** — there's probably an
  older unmanaged file still sitting at a legacy path shadowing it (git
  reads `~/.gitconfig` *after* `~/.config/git/config`, so a stale
  `~/.gitconfig` wins). Check with `readlink -f <path>`; if it doesn't
  point into `/nix/store`, remove the stale file and rebuild — home-manager
  is also configured to back up (`.backup` suffix) rather than silently
  overwrite any unmanaged file it finds in its way.
- **GitHub SSH stopped working after a reboot** — the agent doesn't persist
  loaded keys across reboots; rerun `ssh-add ~/.ssh/id_ed25519_github`
  (Phase 3, step 3).
- **`nixos-install` (or the note's Step 10 dry-run) fails with something
  like "The option `home-manager.users.dannyvelasquez' does not exist"** —
  you're doing the very first install and forgot to strip the
  `home-manager.*` block out of `configuration.nix` first (Phase 1). That
  block depends on `flake.nix`, which isn't in play until the flake-based
  rebuild in Phase 2, after first boot.
- For anything about partitioning, the Broadcom driver, or the password
  hash file, see the "If something goes wrong" section of the
  [install note](https://github.com/dannyvelas/notes/blob/main/vault/how-to-install-nixos-with-kde-plasma-and-broadcom-wifi-on-a-2014-macbook-pro.md).
