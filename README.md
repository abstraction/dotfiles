# Omarchy Dotfiles

This repository is managed by [chezmoi](https://www.chezmoi.io/). It contains configurations tailored for an Omarchy Linux system.

## Setup
1. Install chezmoi (`omarchy pkg add chezmoi` on Omarchy)
2. Run `chezmoi init git@github.com:abstraction/dotfiles.git`
3. Run `chezmoi apply` to apply the configurations.

## Editing Files
Always use `chezmoi edit <file>` rather than editing the target file in `~/.config/` directly.

## keyd Configuration
Because `chezmoi` manages files within the home directory by default, the `keyd` configuration is tracked locally in `~/.config/keyd/default.conf` rather than `/etc/keyd/`. 

When making changes to the key mappings:
1. Edit the file via chezmoi: `chezmoi edit ~/.config/keyd/default.conf`
2. Apply the changes to the system: `sudo cp ~/.config/keyd/default.conf /etc/keyd/default.conf`
3. Reload the daemon: `sudo keyd reload`
