#!/bin/sh

set -eu

theme_file="$HOME/.config/bsdrunner/current-theme"
theme="default"

if [ -f "$theme_file" ]; then
    theme="$(tr -d '\n' < "$theme_file")"
fi

case "$theme" in
    jinteki)
        text="JIN"
        class="jinteki"
        tooltip="Current theme: Jinteki\nClick to switch themes"
        ;;
    haas-bioroid)
        text="HB"
        class="haas-bioroid"
        tooltip="Current theme: Haas-Bioroid\nClick to switch themes"
        ;;
    nbn)
        text="NBN"
        class="nbn"
        tooltip="Current theme: NBN\nClick to switch themes"
        ;;
    weyland)
        text="WYL"
        class="weyland"
        tooltip="Current theme: Weyland Consortium\nClick to switch themes"
        ;;
    *)
        text="DEF"
        class="default"
        tooltip="Current theme: BSDRunner Default\nClick to switch themes"
        ;;
esac

printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tooltip"
