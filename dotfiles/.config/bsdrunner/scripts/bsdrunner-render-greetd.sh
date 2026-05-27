#!/bin/sh

set -eu

config_home="${HOME}/.config"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
installed_runner_home="${config_home}/bsdrunner"
repo_runner_home="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runner_home="$installed_runner_home"
output_dir="${runner_home}/greetd"
install_dir="/etc/greetd/bsdrunner"

usage() {
    cat <<'EOF'
Usage: sh ~/.config/bsdrunner/scripts/bsdrunner-render-greetd.sh [--output DIR] [--install-dir DIR]

Renders a BSDRunner greetd/ReGreet bundle under ~/.config/bsdrunner/greetd by default.

Options:
  --output DIR       Local render target. Default: ~/.config/bsdrunner/greetd
  --install-dir DIR  Final system install path encoded into the generated files.
                     Default: /etc/greetd/bsdrunner
EOF
}

pick_random_line() {
    awk '
        BEGIN {
            srand()
        }

        {
            if (rand() * NR < 1)
                pick = $0
        }

        END {
            if (pick != "")
                print pick
        }
    '
}

static_wallpapers() {
    find "$runner_home/themes" -path '*/wallpapers/*' -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                usage >&2
                exit 1
            }
            output_dir="$2"
            shift
            ;;
        --install-dir)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                usage >&2
                exit 1
            }
            install_dir="$2"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo ":: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [ ! -d "$runner_home/themes" ]; then
    runner_home="$repo_runner_home"
fi

palette_theme="default"
if [ -f "$runner_home/current-theme" ]; then
    palette_theme="$(tr -d '\n' < "$runner_home/current-theme")"
fi

palette_file="$runner_home/themes/$palette_theme/palette.conf"
[ -f "$palette_file" ] || palette_file="$runner_home/themes/default/palette.conf"

# palette.conf already uses shell-style assignments.
. "$palette_file"

wallpaper_count="$(static_wallpapers | sed '/^$/d' | wc -l | tr -d ' ')"
[ "${wallpaper_count:-0}" -gt 0 ] || {
    echo ":: No static BSDRunner wallpapers were found." >&2
    exit 1
}

rm -rf "$output_dir/backgrounds"
mkdir -p "$output_dir/backgrounds"
static_wallpapers | while IFS= read -r wallpaper_path; do
    [ -n "$wallpaper_path" ] || continue
    cp "$wallpaper_path" "$output_dir/backgrounds/$(basename "$wallpaper_path")"
done

cat > "$output_dir/start-greeter-hyprland.sh" <<EOF
#!/bin/sh

set -eu

bundle_dir="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"

if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland -- -c "\$bundle_dir/hyprland.conf"
fi

exec Hyprland -c "\$bundle_dir/hyprland.conf"
EOF
chmod +x "$output_dir/start-greeter-hyprland.sh"

cat > "$output_dir/launch-regreet.sh" <<EOF
#!/bin/sh

set -eu

bundle_dir="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
regreet_bin="regreet"
runtime_config="\$bundle_dir/regreet.runtime.toml"

if ! command -v "\$regreet_bin" >/dev/null 2>&1; then
    echo "regreet is not installed." >&2
    exit 1
fi

pick_random_wallpaper() {
    find "\$bundle_dir/backgrounds" -maxdepth 1 -type f \\
        \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | awk '
        BEGIN {
            srand()
        }

        {
            if (rand() * NR < 1)
                pick = \$0
        }

        END {
            if (pick != "")
                print pick
        }
    '
}

background_path="\$(pick_random_wallpaper || true)"
[ -n "\$background_path" ] || {
    echo "No BSDRunner greeter wallpapers were found." >&2
    exit 1
}

sed "s|__BACKGROUND_PATH__|\$background_path|g" \\
    "\$bundle_dir/regreet.toml.template" > "\$runtime_config"

"\$regreet_bin" \\
    --config "\$runtime_config" \\
    --style "\$bundle_dir/regreet.css"
status="\$?"
hyprctl dispatch exit >/dev/null 2>&1 || true
exit "\$status"
EOF
chmod +x "$output_dir/launch-regreet.sh"

cat > "$output_dir/hyprland.conf" <<EOF
exec-once = sh $install_dir/launch-regreet.sh

env = GTK_USE_PORTAL,0
env = GDK_DEBUG,no-portals

general {
    border_size = 0
    gaps_in = 0
    gaps_out = 0
}

decoration {
    rounding = 0

    shadow {
        enabled = false
    }
}

animations {
    enabled = false
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_hyprland_guiutils_check = true
    force_default_wallpaper = 0
}
EOF

cat > "$output_dir/config.toml" <<EOF
[default_session]
command = "env XDG_DATA_DIRS=/usr/local/share:/usr/share dbus-run-session sh $install_dir/start-greeter-hyprland.sh"
user = "greeter"
EOF

cat > "$output_dir/regreet.toml.template" <<EOF
[background]
path = "__BACKGROUND_PATH__"
fit = "Cover"

[GTK]
application_prefer_dark_theme = true
cursor_blink = true
cursor_theme_name = "Adwaita"
font_name = "JetBrains Mono 14"
icon_theme_name = "Adwaita"
theme_name = "Adwaita"

[commands]
reboot = ["shutdown", "-r", "now"]
poweroff = ["shutdown", "-p", "now"]
x11_prefix = ["startx", "/usr/bin/env"]

[appearance]
greeting_msg = "Welcome to BSDRunner"

[widget.clock]
format = "%a %H:%M"
resolution = "1000ms"
label_width = 150
EOF

cat > "$output_dir/regreet.css" <<EOF
window {
    background-color: rgba(0, 0, 0, 0.18);
    color: $text;
    font-family: "JetBrains Mono";
}

entry,
button,
combobox,
popover,
list,
menu {
    border-radius: 16px;
    border: 2px solid $accent;
    background: $surface;
    color: $text;
    box-shadow: none;
}

entry,
button,
combobox {
    min-height: 44px;
    padding: 10px 14px;
    font-size: 16px;
}

entry:focus,
button:hover,
button:focus,
combobox:focus {
    border-color: $accent_strong;
}

button {
    background: alpha($surface, 0.96);
    font-weight: 700;
}

button:hover,
button:focus {
    background: $accent;
    color: #ffffff;
}

label {
    color: $text;
}
EOF

cat > "$output_dir/README.txt" <<EOF
BSDRunner greetd/ReGreet bundle

Rendered theme palette: $theme_name
Copied wallpapers: $wallpaper_count
Suggested system install path: $install_dir

Copy this directory to the install path above, then copy config.toml to /etc/greetd/config.toml.
EOF

printf '%s\n' ":: Rendered BSDRunner greetd bundle:"
printf '%s\n' "   local bundle: $output_dir"
printf '%s\n' "   copied wallpapers: $wallpaper_count"
printf '%s\n' "   encoded install path: $install_dir"
