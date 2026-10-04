#!/usr/bin/env bash

source "$SCRIPT_DIR/../caching.sh"

quickshell -p "$MAIN_QML" ipc call theme reloadColors >/dev/null 2>&1 &

SERP_SRC="${SERPANTINUM_DIR:-$HOME/.local/share/serpantinum/src}"
if [ -f "$SERP_SRC/scripts/theme/sync_shaders.py" ]; then
    python3 "$SERP_SRC/scripts/theme/sync_shaders.py" >/dev/null 2>&1 &
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../theme/sync_shaders.py" ]; then
    python3 "$SCRIPT_DIR/../theme/sync_shaders.py" >/dev/null 2>&1 &
fi

wait
