-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- Route your video player (e.g., MTV/mpv) to Workspace 7.
-- Workspace 7 is manually pinned as the default for your laptop screen.
o.window("mpv", { workspace = "7" })

o.window({ class = "^wispr-flow$", title = "^(Status|Flow Status Indicator)$" }, {
  float = true,
  pin = true,
-- no_dim = true,
-- no_blur = true,
-- no_shadow = true,
  border_size = 1,
  no_focus = true,
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
  move = { 20, 350 },
})

-- Fix video playback in Hybrid mode by explicitly overriding the Omarchy NVIDIA defaults
local handle = io.popen("supergfxctl -g 2>/dev/null")
if handle then
  local mode = handle:read("*a"):match("^%s*(.-)%s*$")
  handle:close()
  if mode == "Hybrid" or mode == "Integrated" then
    hl.env("LIBVA_DRIVER_NAME", "iHD")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "")
    hl.env("NVD_BACKEND", "")
  end
end

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
