#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

if ! command -v qmllint >/dev/null 2>&1; then
    printf 'qmllint is not installed or not in PATH.\n' >&2
    exit 1
fi

qml_files="
dotfiles/.config/quickshell/bsdrunner-software/shell.qml
dotfiles/.config/quickshell/bsdrunner-software/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-software/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-pf/shell.qml
dotfiles/.config/quickshell/bsdrunner-pf/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-pf/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-welcome/shell.qml
dotfiles/.config/quickshell/bsdrunner-welcome/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-welcome/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-battery/shell.qml
dotfiles/.config/quickshell/bsdrunner-battery/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-battery/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-apps/shell.qml
dotfiles/.config/quickshell/bsdrunner-apps/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-apps/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-dns/shell.qml
dotfiles/.config/quickshell/bsdrunner-dns/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-dns/ThemePalette.qml
"

printf 'Running qmllint...\n'
qmllint $qml_files
