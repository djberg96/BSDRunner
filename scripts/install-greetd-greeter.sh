#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
bundle_dir="/etc/greetd/bsdrunner"
config_path="/usr/local/etc/greetd/config.toml"
backend_path="/usr/local/libexec/bsdrunner-greetd-greeter"
theme=""
activate=false

usage() {
    cat <<'EOF'
Usage: ./scripts/install-greetd-greeter.sh [--theme THEME] [--activate]

Builds the BSDRunner greetd bridge and installs the graphical greeter bundle.
Without --activate, the active greetd config is left unchanged.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --theme)
            [ "$#" -ge 2 ] || { usage >&2; exit 64; }
            theme="$2"
            shift
            ;;
        --activate)
            activate=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '%s\n' "Unknown option: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
    shift
done

if [ -z "$theme" ] && [ -f "$HOME/.config/bsdrunner/current-theme" ]; then
    theme="$(tr -d '[:space:]' < "$HOME/.config/bsdrunner/current-theme")"
fi
theme="${theme:-default}"
theme_dir="$repo_root/dotfiles/.config/bsdrunner/themes/$theme"

[ -f "$theme_dir/palette.conf" ] || {
    printf '%s\n' "Unknown or incomplete BSDRunner theme: $theme" >&2
    exit 1
}
command -v cargo >/dev/null 2>&1 || {
    printf '%s\n' "cargo is required to build the greetd bridge." >&2
    exit 1
}
command -v mdo >/dev/null 2>&1 || {
    printf '%s\n' "mdo is required to install the system greeter bundle." >&2
    exit 1
}

cargo build --locked --release --manifest-path "$repo_root/greeter/Cargo.toml"

static_wallpapers() {
    find "$1/wallpapers" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \)
}

greeter_themes() {
    for candidate_dir in "$repo_root/dotfiles/.config/bsdrunner/themes"/*; do
        [ -f "$candidate_dir/palette.conf" ] || continue
        [ -d "$candidate_dir/wallpapers" ] || continue
        candidate="$(basename -- "$candidate_dir")"
        [ -n "$(static_wallpapers "$candidate_dir")" ] || continue
        printf '%s\n' "$candidate"
    done
}

greeter_themes | grep -q . || {
    printf '%s\n' "No BSDRunner wallpapers were found." >&2
    exit 1
}

stamp="$(date +%Y%m%d-%H%M%S)"
if [ -d "$bundle_dir" ]; then
    mdo cp -Rp "$bundle_dir" "$bundle_dir.pre-bsdrunner-$stamp"
fi

mdo install -d -m 0755 \
    "$bundle_dir" \
    "$bundle_dir/quickshell" \
    "$bundle_dir/themes" \
    /usr/local/libexec

mdo install -m 0755 \
    "$repo_root/greeter/target/release/bsdrunner-greetd-greeter" \
    "$backend_path"
mdo install -m 0755 \
    "$repo_root/greeter/start-greeter-hyprland.sh" \
    "$repo_root/greeter/launch-greeter.sh" \
    "$bundle_dir/"
mdo install -m 0644 \
    "$repo_root/greeter/hyprland.lua" \
    "$bundle_dir/hyprland.lua"
# The bundle was backed up above, so remove the obsolete config after its Lua
# replacement is safely installed.
mdo rm -f "$bundle_dir/hyprland.conf"
mdo install -m 0644 \
    "$repo_root/dotfiles/.config/quickshell/bsdrunner-greeter/shell.qml" \
    "$repo_root/dotfiles/.config/quickshell/bsdrunner-greeter/ThemeLoader.qml" \
    "$repo_root/dotfiles/.config/quickshell/bsdrunner-greeter/ThemePalette.qml" \
    "$bundle_dir/quickshell/"

greeter_themes | while IFS= read -r greeter_theme; do
    source_theme_dir="$repo_root/dotfiles/.config/bsdrunner/themes/$greeter_theme"
    installed_theme_dir="$bundle_dir/themes/$greeter_theme"
    mdo install -d -m 0755 "$installed_theme_dir" "$installed_theme_dir/wallpapers"
    mdo install -m 0644 "$source_theme_dir/palette.conf" "$installed_theme_dir/palette.conf"
    find "$source_theme_dir/wallpapers" -maxdepth 1 -type f | while IFS= read -r wallpaper; do
        mdo install -m 0644 "$wallpaper" "$installed_theme_dir/wallpapers/$(basename "$wallpaper")"
    done
done

# Keep the configured theme installed as a fallback even when it has no
# wallpapers of its own (the neutral default theme is the common case).
if [ ! -f "$bundle_dir/themes/$theme/palette.conf" ]; then
    mdo install -d -m 0755 "$bundle_dir/themes/$theme"
    mdo install -m 0644 "$theme_dir/palette.conf" "$bundle_dir/themes/$theme/palette.conf"
fi
printf '%s\n' "$theme" | mdo tee "$bundle_dir/current-theme" >/dev/null
mdo chmod 0644 "$bundle_dir/current-theme"
mdo install -m 0644 "$repo_root/greeter/greetd.toml" "$bundle_dir/config.toml"

if [ "$activate" = true ]; then
    if [ -f "$config_path" ]; then
        mdo cp -p "$config_path" "$config_path.pre-bsdrunner-$stamp"
    fi
    mdo install -m 0644 "$repo_root/greeter/greetd.toml" "$config_path"
fi

printf '%s\n' ":: Installed BSDRunner greetd greeter (fallback: $theme; randomized themes: $(greeter_themes | tr '\n' ' ' | sed 's/ $//'))"
printf '%s\n' "   bundle:  $bundle_dir"
printf '%s\n' "   backend: $backend_path"
if [ "$activate" = true ]; then
    printf '%s\n' "   active config: $config_path"
else
    printf '%s\n' "   greetd config staged at: $bundle_dir/config.toml"
    printf '%s\n' "   rerun with --activate when ready"
fi
