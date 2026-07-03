#!/usr/bin/env bash
# One-click launcher for Race Wheel (Linux / macOS).
# Finds an installed Godot 4.3 or downloads a local copy, then plays.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
VER="4.3-stable"
BIN_DIR="$DIR/.godot-bin"

# 1) Find an existing Godot before downloading:
#    $GODOT override -> PATH -> a 'godot' shell alias -> common install spots.
find_existing_godot() {
    # Explicit override.
    if [ -n "$GODOT" ] && [ -x "$GODOT" ]; then printf '%s' "$GODOT"; return; fi
    # On PATH.
    for c in godot godot4; do
        if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return; fi
    done
    # Scripts can't run aliases, but we can read them: alias godot="/path/to/Godot"
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.profile"; do
        [ -f "$rc" ] || continue
        local line cand
        line="$(grep -E '^[[:space:]]*alias[[:space:]]+godot=' "$rc" 2>/dev/null | head -n1)" || true
        [ -n "$line" ] || continue
        cand="${line#*=}"
        cand="$(printf '%s' "$cand" | tr -d "\"'" | awk '{print $1}')"
        cand="${cand/#\~/$HOME}"
        [ -x "$cand" ] && { printf '%s' "$cand"; return; }
    done
    # Common install locations.
    for g in "$HOME"/project/tools/Godot* /opt/godot* /usr/local/bin/godot* "$HOME"/.local/bin/godot* "$HOME"/Godot*; do
        case "$g" in *.zip) continue;; esac
        [ -f "$g" ] && [ -x "$g" ] && { printf '%s' "$g"; return; }
    done
    printf ''
}
GODOT="$(find_existing_godot)"

# 2) Otherwise download a local copy (no system install needed).
if [ -z "$GODOT" ]; then
    OS="$(uname -s)"
    case "$OS" in
        Linux)
            URL="https://github.com/godotengine/godot/releases/download/$VER/Godot_v${VER}_linux.x86_64.zip"
            EXE="$BIN_DIR/Godot_v${VER}_linux.x86_64" ;;
        Darwin)
            URL="https://github.com/godotengine/godot/releases/download/$VER/Godot_v${VER}_macos.universal.zip"
            EXE="$BIN_DIR/Godot.app/Contents/MacOS/Godot" ;;
        *)
            echo "Unsupported OS: $OS — please install Godot 4.3 manually." ; exit 1 ;;
    esac

    if [ ! -x "$EXE" ]; then
        echo "Godot not found. Downloading Godot $VER (one-time, ~70 MB)..."
        mkdir -p "$BIN_DIR"
        ZIP="$BIN_DIR/godot.zip"
        if command -v curl >/dev/null 2>&1; then
            curl -L -o "$ZIP" "$URL"
        else
            wget -O "$ZIP" "$URL"
        fi
        unzip -o "$ZIP" -d "$BIN_DIR"
        rm -f "$ZIP"
        chmod +x "$EXE" 2>/dev/null || true
    fi
    GODOT="$EXE"
fi

# 3) First run: build the asset import cache (no .godot yet).
if [ ! -d "$DIR/.godot/imported" ]; then
    echo "Importing assets (first run), please wait..."
    "$GODOT" --path "$DIR" --headless --import || true
fi

echo "Launching Race Wheel with: $GODOT"
exec "$GODOT" --path "$DIR"
