local user_home = os.getenv("HOME") or "/home/statics"

-- Load HyprWindowShade plugin for custom GLSL open/close fragment shaders
hl.plugin.load(user_home .. "/.local/share/hyprland/plugins/HyprWindowShade.so")

-- Window shader rules: Liquid glass wave with chromatic refraction & caustics
hl.window_rule({
  match = { class = ".*" },
  tag   = "+shader_open_default:" .. user_home .. "/.config/hypr/shaders/liquid_open.glsl@0.50",
})
hl.window_rule({
  match = { class = ".*" },
  tag   = "+shader_close_default:" .. user_home .. "/.config/hypr/shaders/liquid_close.glsl@0.24",
})

-- Fix: prevent windows (like Kitty) from auto-maximizing over existing tiled windows
hl.window_rule({
  name  = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Dynamic Serpantinum palette loader: reads active theme from qs_colors.json
local function load_serpantinum_theme()
  local home = os.getenv("HOME") or "/home/statics"
  local path = home .. "/.local/state/serpantinum/qs_colors.json"
  local f = io.open(path, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  local colors = {}
  for k, v in content:gmatch('"([%w_]+)"%s*:%s*"#([%x]+)"') do
    colors[k] = v
  end
  return colors
end

local serp_theme = load_serpantinum_theme()
local col_active1 = serp_theme.mauve or "cba6f7"
local col_active2 = (serp_theme.sapphire ~= serp_theme.mauve and serp_theme.sapphire) or serp_theme.blue or "89b4fa"
local col_inactive = serp_theme.surface0 or "313244"

hl.config({
  general = {
    layout = "dwindle",
    border_size = 2,
    col = {
      active_border = {
        colors = { "rgba(" .. col_active1 .. "ee)", "rgba(" .. col_active2 .. "ee)" },
        angle = 45,
      },
      inactive_border = "rgba(" .. col_inactive .. "88)",
    },
    gaps_in = 5,
    gaps_out = 8,
    float_gaps = 8,
    resize_on_border = true,
    extend_border_grab_area = 30,
  },

  dwindle = {
    preserve_split = true,
    smart_split = false,
  },

  decoration = {
    rounding = 14,
    active_opacity = 0.98,
    inactive_opacity = 0.92,
    dim_inactive = true,
    dim_strength = 0.10,
    shadow = {
      enabled = true,
      range = 14,
      render_power = 2, -- Clean 2-pass shadow (zero FPS drops on 165Hz)
      color = 0x66000000,
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      new_optimizations = true,
      xray = false,
      vibrancy = 0.25,
      contrast = 1.10,
      brightness = 0.95,
    },
  },

  input = {
    kb_layout = "us,ru",
    kb_options = "grp:alt_shift_toggle",
    accel_profile = "flat",
    touchpad = {
      natural_scroll = true,
      disable_while_typing = false,
    },
  },

  misc = {
    focus_on_activate = false,
    font_family = "JetBrains Mono",
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})

-- Top-tier community curves
hl.curve("wind",        { type = "bezier", points = { {0.05, 0.9},   {0.1, 1.05}  } })
hl.curve("md3_decel",   { type = "bezier", points = { {0.05, 0.7},   {0.1, 1.0}   } })
hl.curve("md3_accel",   { type = "bezier", points = { {0.3, 0.0},    {0.8, 0.15}  } })
hl.curve("serpantina",  { type = "bezier", points = { {0.25, 0.7},   {0.30, 1.0}  } })

-- 165Hz Serpantinum animations (popin 100% = instant tiled geometry, fluid shader handles appearance)
hl.animation({ leaf = "windows",             enabled = true, speed = 5.0, bezier = "serpantina", style = "popin 100%" })
hl.animation({ leaf = "windowsIn",           enabled = true, speed = 5.0, bezier = "serpantina", style = "popin 100%" })
hl.animation({ leaf = "windowsOut",          enabled = false }) -- Handled entirely by liquid_close.glsl
hl.animation({ leaf = "windowsMove",         enabled = true, speed = 4.0, bezier = "serpantina" })
hl.animation({ leaf = "border",              enabled = true, speed = 4.5, bezier = "serpantina" })
hl.animation({ leaf = "borderangle",         enabled = false })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 5.0, bezier = "serpantina" })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 2.4, bezier = "serpantina" })
hl.animation({ leaf = "fade",                enabled = true, speed = 3.5, bezier = "serpantina" })
hl.animation({ leaf = "fadeSwitch",          enabled = true, speed = 2.4, bezier = "serpantina" })
hl.animation({ leaf = "fadeShadow",          enabled = true, speed = 2.4, bezier = "serpantina" })
hl.animation({ leaf = "fadeDim",             enabled = true, speed = 2.5, bezier = "serpantina" })
hl.animation({ leaf = "layers",              enabled = true, speed = 2.5, bezier = "serpantina" })
hl.animation({ leaf = "layersIn",            enabled = true, speed = 2.5, bezier = "serpantina" })
hl.animation({ leaf = "layersOut",           enabled = true, speed = 2.0, bezier = "serpantina" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 3.2, bezier = "wind", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2.0, bezier = "serpantina", style = "fade" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.8, bezier = "serpantina", style = "fade" })
