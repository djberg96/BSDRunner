#!/bin/sh

set -eu

config_home="${HOME}/.config"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
installed_runner_home="${config_home}/bsdrunner"
repo_runner_home="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runner_home="$installed_runner_home"
output_dir="${installed_runner_home}/lightdm"
install_prefix="/usr/local"

usage() {
    cat <<'EOF'
Usage: sh ~/.config/bsdrunner/scripts/bsdrunner-render-lightdm.sh [--output DIR] [--prefix DIR]

Renders a BSDRunner LightDM bundle under ~/.config/bsdrunner/lightdm by default.

Options:
  --output DIR  Local render target. Default: ~/.config/bsdrunner/lightdm
  --prefix DIR  Final system prefix encoded into generated files.
                Default: /usr/local
EOF
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
        --prefix)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                usage >&2
                exit 1
            }
            install_prefix="$2"
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
. "$palette_file"

wallpaper_count="$(static_wallpapers | sed '/^$/d' | wc -l | tr -d ' ')"
[ "${wallpaper_count:-0}" -gt 0 ] || {
    echo ":: No static BSDRunner wallpapers were found." >&2
    exit 1
}

bundle_root="$output_dir"
lightdm_etc_dir="$bundle_root/etc/lightdm"
lightdm_conf_d_dir="$lightdm_etc_dir/lightdm.conf.d"
lightdm_share_dir="$bundle_root/share/bsdrunner/lightdm"
xgreeters_dir="$bundle_root/share/xgreeters"
backgrounds_dir="$lightdm_share_dir/backgrounds"

rm -rf "$bundle_root"
mkdir -p "$lightdm_conf_d_dir" "$backgrounds_dir" "$xgreeters_dir"

static_wallpapers | while IFS= read -r wallpaper_path; do
    [ -n "$wallpaper_path" ] || continue
    cp "$wallpaper_path" "$backgrounds_dir/$(basename "$wallpaper_path")"
done

cat > "$lightdm_share_dir/pick-random-wallpaper.sh" <<EOF
#!/bin/sh

set -eu

bundle_dir="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
backgrounds_dir="\$bundle_dir/backgrounds"
current_target="/tmp/bsdrunner-lightdm-current-background"

pick_random_wallpaper() {
    find "\$backgrounds_dir" -maxdepth 1 -type f \\
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

wallpaper_path="\$(pick_random_wallpaper || true)"
[ -n "\$wallpaper_path" ] || exit 1

ln -sfn "\$wallpaper_path" "\$current_target"
EOF
chmod +x "$lightdm_share_dir/pick-random-wallpaper.sh"

cat > "$lightdm_share_dir/bsdrunner-lightdm-gtk-greeter" <<EOF
#!/bin/sh

set -eu

bundle_dir="$install_prefix/share/bsdrunner/lightdm"
picker="\$bundle_dir/pick-random-wallpaper.sh"
greeter_bin="$install_prefix/sbin/lightdm-gtk-greeter"

if [ -x "\$picker" ]; then
    sh "\$picker" >/dev/null 2>&1 || true
fi

exec "\$greeter_bin"
EOF
chmod +x "$lightdm_share_dir/bsdrunner-lightdm-gtk-greeter"

cat > "$xgreeters_dir/bsdrunner-lightdm-gtk-greeter.desktop" <<EOF
[Desktop Entry]
Name=BSDRunner LightDM GTK Greeter
Comment=BSDRunner wallpaper-aware LightDM GTK greeter
Exec=$install_prefix/share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter
Type=Application
X-LightDM-Session-Type=x
EOF

cat > "$lightdm_conf_d_dir/50-bsdrunner.conf" <<EOF
[Seat:*]
greeter-session=bsdrunner-lightdm-gtk-greeter
xserver-command=$install_prefix/bin/Xorg
EOF

cat > "$lightdm_etc_dir/lightdm-gtk-greeter.conf" <<EOF
[greeter]
background=/tmp/bsdrunner-lightdm-current-background
theme-name=Adwaita
icon-theme-name=Adwaita
font-name=JetBrains Mono 14
indicators=~host;~spacer;~clock;~spacer;~layout;~session;~a11y;~power
clock-format=%a %H:%M
user-background=false
EOF

cat > "$bundle_root/README.txt" <<EOF
BSDRunner LightDM bundle

Rendered theme palette: $theme_name
Copied wallpapers: $wallpaper_count
Encoded install prefix: $install_prefix

Copy:
  $bundle_root/etc/lightdm/.            -> $install_prefix/etc/lightdm/
  $bundle_root/share/bsdrunner/lightdm/ -> $install_prefix/share/bsdrunner/lightdm/
  $bundle_root/share/xgreeters/.        -> $install_prefix/share/xgreeters/
EOF

printf '%s\n' ":: Rendered BSDRunner LightDM bundle:"
printf '%s\n' "   local bundle: $bundle_root"
printf '%s\n' "   copied wallpapers: $wallpaper_count"
printf '%s\n' "   encoded prefix: $install_prefix"
