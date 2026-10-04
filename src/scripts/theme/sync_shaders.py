#!/usr/bin/env python3
"""
sync_shaders.py - Synchronize Hyprland window shaders, borders, Kitty terminal,
and Starship prompt with active Serpantinum theme.

Reads ~/.local/state/serpantinum/qs_colors.json (the active theme palette generated
by Serpantinum / Matugen) and dynamically updates:
  1. ~/.config/hypr/shaders/liquid_open.glsl (Mauve, Sapphire, Blue accents + border caustics)
  2. ~/.config/hypr/shaders/liquid_close.glsl (dissolve rim glow)
  3. Hyprland active and inactive window border colors via hyprctl eval
  4. HyprWindowShade reloads shaders with new colors
  5. ~/.config/kitty/colors.conf (full 16 ANSI colors, background, foreground, cursor)
  6. ~/.config/starship.toml ([palettes.serpantinum] palette for directory & character)
  7. Signals Kitty to reload colors live via SIGUSR1
"""

import sys
import os
import re
import json
import time
import subprocess

STATE_FILE = os.path.expanduser("~/.local/state/serpantinum/qs_colors.json")
MATUGEN_FILE = os.path.expanduser("~/.local/state/serpantinum/qs_matugen_colors.json")
SETTINGS_FILE = os.path.expanduser("~/.config/serpantinum/settings.json")
OPEN_SHADER = os.path.expanduser("~/.config/hypr/shaders/liquid_open.glsl")
CLOSE_SHADER = os.path.expanduser("~/.config/hypr/shaders/liquid_close.glsl")
KITTY_COLORS = os.path.expanduser("~/.config/kitty/colors.conf")
STARSHIP_CONFIG = os.path.expanduser("~/.config/starship.toml")

def hex_to_vec3(hex_code, default_rgb=(0.8, 0.65, 0.97)):
    if not hex_code:
        return f"vec3({default_rgb[0]:.3f}, {default_rgb[1]:.3f}, {default_rgb[2]:.3f})"
    h = str(hex_code).lstrip("#")
    if len(h) == 6:
        r = int(h[0:2], 16) / 255.0
        g = int(h[2:4], 16) / 255.0
        b = int(h[4:6], 16) / 255.0
        return f"vec3({r:.3f}, {g:.3f}, {b:.3f})"
    return f"vec3({default_rgb[0]:.3f}, {default_rgb[1]:.3f}, {default_rgb[2]:.3f})"

def is_matugen_theme():
    if os.path.isfile(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                theme = data.get("theme", {})
                if theme.get("matugen") is True or theme.get("activePreset") in ("Matugen", None):
                    return True
        except Exception:
            pass
    return False

def load_colors():
    use_matugen = is_matugen_theme()
    candidates = [MATUGEN_FILE, STATE_FILE] if use_matugen else [STATE_FILE, MATUGEN_FILE]

    for fpath in candidates:
        if os.path.isfile(fpath):
            try:
                with open(fpath, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        colors = data.get("colors", data)
                        if colors and isinstance(colors, dict) and ("mauve" in colors or "blue" in colors):
                            return colors
            except Exception as e:
                print(f"Warning: failed to read {fpath}: {e}", file=sys.stderr)

    if os.path.isfile(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                theme = data.get("theme", {})
                colors = theme.get("colors", {})
                if colors and isinstance(colors, dict):
                    return colors
        except Exception as e:
            print(f"Warning: failed to read {SETTINGS_FILE}: {e}", file=sys.stderr)

    return {}

def sync():
    colors = load_colors()
    if not colors:
        print("No colors found to sync.")
        return False

    base_hex = colors.get("base") or "#140c0b"
    text_hex = colors.get("text") or "#f1dedc"
    surface0_hex = colors.get("surface0") or "#271d1c"
    surface1_hex = colors.get("surface1") or "#322826"
    surface2_hex = colors.get("surface2") or "#3d3231"
    subtext0_hex = colors.get("subtext0") or "#d8c2be"
    crust_hex = colors.get("crust") or "#100908"

    mauve_hex = colors.get("mauve") or colors.get("red") or "#ffb4a9"
    sapphire_hex = colors.get("sapphire") or colors.get("teal") or colors.get("blue") or "#74c7ec"
    blue_hex = colors.get("blue") or colors.get("sapphire") or "#ffb4a9"
    peach_hex = colors.get("peach") or "#dfc38c"
    green_hex = colors.get("green") or "#e7bdb7"
    red_hex = colors.get("red") or "#ffb4ab"
    maroon_hex = colors.get("maroon") or "#93000a"
    teal_hex = colors.get("teal") or colors.get("green") or "#e7bdb7"
    yellow_hex = colors.get("yellow") or colors.get("peach") or "#5d3f3b"
    pink_hex = colors.get("pink") or "#574419"

    vec_mauve = hex_to_vec3(mauve_hex, (0.796, 0.651, 0.969))
    vec_sapphire = hex_to_vec3(sapphire_hex, (0.455, 0.780, 0.925))
    vec_blue = hex_to_vec3(blue_hex, (0.537, 0.706, 0.980))

    # 1. Update liquid_open.glsl
    if os.path.isfile(OPEN_SHADER):
        with open(OPEN_SHADER, "r", encoding="utf-8") as f:
            open_code = f.read()

        open_repl = (
            f"// BEGIN_SERPANTINUM_THEME_COLORS\n"
            f"    vec3 colMauve    = {vec_mauve}; // {mauve_hex}\n"
            f"    vec3 colSapphire = {vec_sapphire}; // {sapphire_hex}\n"
            f"    vec3 colBlue     = {vec_blue}; // {blue_hex}\n"
            f"    // END_SERPANTINUM_THEME_COLORS"
        )

        pattern = r"// BEGIN_SERPANTINUM_THEME_COLORS[\s\S]*?// END_SERPANTINUM_THEME_COLORS"
        if re.search(pattern, open_code):
            open_code = re.sub(pattern, open_repl, open_code)
        else:
            pattern_init = r"vec3 colMauve\s*=\s*vec3\([^)]+\);\s*vec3 colSapphire\s*=\s*vec3\([^)]+\);\s*vec3 colBlue\s*=\s*vec3\([^)]+\);"
            if re.search(pattern_init, open_code):
                open_code = re.sub(pattern_init, open_repl, open_code)

        with open(OPEN_SHADER, "w", encoding="utf-8") as f:
            f.write(open_code)

    # 2. Update liquid_close.glsl
    if os.path.isfile(CLOSE_SHADER):
        with open(CLOSE_SHADER, "r", encoding="utf-8") as f:
            close_code = f.read()

        close_repl = (
            f"// BEGIN_SERPANTINUM_THEME_COLORS\n"
            f"    vec3 colMauve = {vec_mauve}; // {mauve_hex}\n"
            f"    vec3 colBlue  = {vec_blue}; // {blue_hex}\n"
            f"    // END_SERPANTINUM_THEME_COLORS"
        )

        pattern = r"// BEGIN_SERPANTINUM_THEME_COLORS[\s\S]*?// END_SERPANTINUM_THEME_COLORS"
        if re.search(pattern, close_code):
            close_code = re.sub(pattern, close_repl, close_code)
        else:
            pattern_init = r"vec3 colMauve\s*=\s*vec3\([^)]+\);\s*vec3 colBlue\s*=\s*vec3\([^)]+\);"
            if re.search(pattern_init, close_code):
                close_code = re.sub(pattern_init, close_repl, close_code)

        with open(CLOSE_SHADER, "w", encoding="utf-8") as f:
            f.write(close_code)

    # 3. Update Hyprland borders dynamically via hyprctl eval
    c1 = mauve_hex.lstrip("#")
    c2 = sapphire_hex.lstrip("#") if sapphire_hex != mauve_hex else blue_hex.lstrip("#")
    cs = surface0_hex.lstrip("#")

    eval_cmd = (
        f'hl.config({{ general = {{ col = {{ '
        f'active_border = {{ colors = {{ "rgba({c1}ee)", "rgba({c2}ee)" }}, angle = 45 }}, '
        f'inactive_border = "rgba({cs}88)" }} }} }})'
    )
    subprocess.run(["hyprctl", "eval", eval_cmd], capture_output=True)

    # 4. Trigger HyprWindowShade shader reload
    subprocess.run(["hyprctl", "eval", "hl.plugin.HyprWindowShade.reloadshaders()"], capture_output=True)

    # 5. Update ~/.config/kitty/colors.conf
    kitty_content = f"""# Serpantinum dynamic theme for Kitty
foreground              {text_hex}
background              {base_hex}
selection_foreground    {text_hex}
selection_background    {surface2_hex}

cursor                  {mauve_hex}
cursor_text_color       {base_hex}

url_color               {sapphire_hex}

active_border_color     {mauve_hex}
inactive_border_color   {surface0_hex}
bell_border_color       {red_hex}

wayland_titlebar_color  system
macos_titlebar_color    system

active_tab_foreground   {base_hex}
active_tab_background   {mauve_hex}
inactive_tab_foreground {subtext0_hex}
inactive_tab_background {surface0_hex}
tab_bar_background      {crust_hex}

mark1_foreground {base_hex}
mark1_background {mauve_hex}
mark2_foreground {base_hex}
mark2_background {blue_hex}
mark3_foreground {base_hex}
mark3_background {sapphire_hex}

# 16 terminal colors
color0 {surface0_hex}
color8 {surface2_hex}

color1 {red_hex}
color9 {maroon_hex}

color2  {green_hex}
color10 {teal_hex}

color3  {yellow_hex}
color11 {peach_hex}

color4  {blue_hex}
color12 {sapphire_hex}

color5  {mauve_hex}
color13 {pink_hex}

color6  {teal_hex}
color14 {sapphire_hex}

color7  {subtext0_hex}
color15 {text_hex}
"""
    try:
        os.makedirs(os.path.dirname(KITTY_COLORS), exist_ok=True)
        with open(KITTY_COLORS, "w", encoding="utf-8") as f:
            f.write(kitty_content)
    except Exception as e:
        print(f"Warning: failed to write {KITTY_COLORS}: {e}", file=sys.stderr)

    # 6. Update ~/.config/starship.toml
    if os.path.isfile(STARSHIP_CONFIG):
        try:
            with open(STARSHIP_CONFIG, "r", encoding="utf-8") as f:
                star_code = f.read()

            star_repl = (
                f"# BEGIN_SERPANTINUM_PALETTE\n"
                f"[palettes.serpantinum]\n"
                f'mauve = "{mauve_hex}"\n'
                f'sapphire = "{sapphire_hex}"\n'
                f'blue = "{blue_hex}"\n'
                f'peach = "{peach_hex}"\n'
                f'green = "{green_hex}"\n'
                f'red = "{red_hex}"\n'
                f'surface0 = "{surface0_hex}"\n'
                f'text = "{text_hex}"\n'
                f"# END_SERPANTINUM_PALETTE"
            )
            pattern_star = r"# BEGIN_SERPANTINUM_PALETTE[\s\S]*?# END_SERPANTINUM_PALETTE"
            if re.search(pattern_star, star_code):
                star_code = re.sub(pattern_star, star_repl, star_code)
                with open(STARSHIP_CONFIG, "w", encoding="utf-8") as f:
                    f.write(star_code)
        except Exception as e:
            print(f"Warning: failed to update {STARSHIP_CONFIG}: {e}", file=sys.stderr)

    # 7. Reload Kitty live
    subprocess.run(["pkill", "-SIGUSR1", "kitty"], capture_output=True)
    subprocess.run(["killall", "-USR1", ".kitty-wrapped"], capture_output=True)

    print(f"Synced Serpantinum colors -> Mauve: {mauve_hex}, Sapphire: {sapphire_hex}, Blue: {blue_hex}, Base: {base_hex}")
    return True

def watch():
    print("Watching Serpantinum theme changes...")
    files_to_watch = [STATE_FILE, MATUGEN_FILE, SETTINGS_FILE]
    last_mtimes = {f: os.path.getmtime(f) if os.path.exists(f) else 0.0 for f in files_to_watch}

    sync()

    while True:
        try:
            time.sleep(0.5)
            changed = False
            for f in files_to_watch:
                if os.path.exists(f):
                    cur_m = os.path.getmtime(f)
                    if cur_m > last_mtimes.get(f, 0.0):
                        last_mtimes[f] = cur_m
                        changed = True
            if changed:
                sync()
        except KeyboardInterrupt:
            break
        except Exception as e:
            time.sleep(1)

if __name__ == "__main__":
    if "--watch" in sys.argv:
        watch()
    else:
        sync()
