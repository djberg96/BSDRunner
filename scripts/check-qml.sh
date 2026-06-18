#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

qmllint_bin="${QMLLINT:-}"
if [ -z "$qmllint_bin" ]; then
    for candidate in \
        qmllint \
        /usr/local/lib/qt6/bin/qmllint; do
        if command -v "$candidate" >/dev/null 2>&1; then
            qmllint_bin="$candidate"
            break
        fi
    done
fi

if [ -z "$qmllint_bin" ]; then
    printf 'Qt 6 qmllint is not installed or not in PATH.\n' >&2
    printf 'On FreeBSD it is provided by qt6-declarative and usually lives at /usr/local/lib/qt6/bin/qmllint.\n' >&2
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
dotfiles/.config/quickshell/bsdrunner-files/shell.qml
dotfiles/.config/quickshell/bsdrunner-files/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-files/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-dns/shell.qml
dotfiles/.config/quickshell/bsdrunner-dns/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-dns/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-zfs/shell.qml
dotfiles/.config/quickshell/bsdrunner-zfs/ThemeLoader.qml
dotfiles/.config/quickshell/bsdrunner-zfs/ThemePalette.qml
dotfiles/.config/quickshell/bsdrunner-memory/shell.qml
"

printf 'Running qmllint...\n'
"$qmllint_bin" $qml_files
