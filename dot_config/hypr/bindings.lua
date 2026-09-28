-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Workaround for Wispr Flow issue #53 (stuck modifiers)
local reset_cmd = "omarchy-reset-modifiers"

-- Standard combination and variants for when Ctrl or Shift is logically stuck
o.bind("SUPER + ALT + W", "Reset stuck modifiers", reset_cmd)
o.bind("CTRL + SUPER + ALT + W", "Reset stuck modifiers (Ctrl stuck)", reset_cmd)
o.bind("SHIFT + SUPER + ALT + W", "Reset stuck modifiers (Shift stuck)", reset_cmd)
o.bind("CTRL + SHIFT + SUPER + ALT + W", "Reset stuck modifiers (Ctrl+Shift stuck)", reset_cmd)

-- Emergency single-key panic button (F12) across modifier permutations so it works no matter what is stuck
local f12_combos = {
  "F12",
  "CTRL + F12",
  "ALT + F12",
  "SUPER + F12",
  "SHIFT + F12",
  "CTRL + ALT + F12",
  "CTRL + SUPER + F12",
  "CTRL + SHIFT + F12",
  "ALT + SUPER + F12",
  "SUPER + SHIFT + F12",
  "CTRL + ALT + SUPER + F12",
  "CTRL + ALT + SUPER + SHIFT + F12",
}
for _, combo in ipairs(f12_combos) do
  o.bind(combo, "Emergency modifier reset", reset_cmd)
end

