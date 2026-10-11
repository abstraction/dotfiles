#!/bin/bash
# Sync active Omarchy theme to Glow style sheet
if [[ -f "$HOME/.local/state/omarchy/current/theme/glow.json" ]]; then
  cp "$HOME/.local/state/omarchy/current/theme/glow.json" "$HOME/.config/glow/omarchy.json"
fi
