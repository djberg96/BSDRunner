#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-theme-test.XXXXXX")"
bundle="$test_root/bundle"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$bundle/themes" "$test_root/bin" "$test_root/runtime"
cp "$repo_root/greeter/launch-greeter.sh" "$bundle/launch-greeter.sh"
printf '%s\n' 'haas-bioroid' >"$bundle/current-theme"

for theme in haas-bioroid jinteki nbn weyland; do
    mkdir -p "$bundle/themes/$theme/wallpapers"
    printf 'theme_name=%s\n' "$theme" >"$bundle/themes/$theme/palette.conf"
    : >"$bundle/themes/$theme/wallpapers/$theme-wallpaper.jpg"
done

printf '%s\n' \
    '#!/bin/sh' \
    'printf '\''%s\n%s\n%s\n'\'' \' \
    '    "$BSDRUNNER_GREETER_THEME" \' \
    '    "$BSDRUNNER_GREETER_WALLPAPER" \' \
    '    "$BSDRUNNER_GREETER_DIR" \' \
    '    >"$BSDRUNNER_GREETER_TEST_OUTPUT"' \
    >"$test_root/bin/qs"
chmod +x "$test_root/bin/qs"

printf '%s\n' '#!/bin/sh' 'exit 0' >"$test_root/bin/hyprctl"
chmod +x "$test_root/bin/hyprctl"

run_greeter() {
    output="$1"
    shift
    env "$@" \
        BSDRUNNER_GREETER_TEST_OUTPUT="$output" \
        XDG_RUNTIME_DIR="$test_root/runtime" \
        PATH="$test_root/bin:/bin:/usr/bin:/usr/local/bin" \
        sh "$bundle/launch-greeter.sh"
}

for theme in haas-bioroid jinteki nbn weyland; do
    output="$test_root/$theme.output"
    run_greeter "$output" BSDRUNNER_GREETER_THEME="$theme"
    [ "$(sed -n '1p' "$output")" = "$theme" ]
    [ "$(sed -n '2p' "$output")" = "$bundle/themes/$theme/wallpapers/$theme-wallpaper.jpg" ]
    [ "$(sed -n '3p' "$output")" = "$bundle" ]
done

output="$test_root/random.output"
run_greeter "$output" -u BSDRUNNER_GREETER_THEME
selected_theme="$(sed -n '1p' "$output")"
selected_wallpaper="$(sed -n '2p' "$output")"
case "$selected_theme" in
    haas-bioroid|jinteki|nbn|weyland) ;;
    *) exit 1 ;;
esac
[ "$selected_wallpaper" = "$bundle/themes/$selected_theme/wallpapers/$selected_theme-wallpaper.jpg" ]

printf '%s\n' 'greeter theme randomizer tests passed'
