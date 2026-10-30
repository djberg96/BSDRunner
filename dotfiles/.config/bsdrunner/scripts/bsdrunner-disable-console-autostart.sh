#!/bin/sh

set -eu

profile="${HOME}/.profile"
check_only=false

usage() {
    cat <<'EOF'
Usage: bsdrunner-disable-console-autostart.sh [--check] [--profile FILE]

Removes the old ttyv0 block that immediately execs start-hyprland. A copy of
the original profile is retained as FILE.pre-bsdrunner-lightdm.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check)
            check_only=true
            ;;
        --profile)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                exit 1
            }
            profile="$2"
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

[ -f "$profile" ] || {
    echo ":: Profile does not exist: $profile" >&2
    exit 1
}

if ! grep -Eq '^[[:space:]]*exec[[:space:]]+start-hyprland([[:space:]]|$)' "$profile"; then
    echo ":: No start-hyprland console autostart is present in $profile"
    exit 0
fi

profile_dir="$(CDPATH= cd -- "$(dirname -- "$profile")" && pwd)"
temporary_profile="$(mktemp "$profile_dir/.bsdrunner-profile.XXXXXX")"
trap 'rm -f "$temporary_profile"' EXIT HUP INT TERM

if ! awk '
    BEGIN {
        capturing = 0
        removed = 0
        block = ""
    }

    !capturing && /\/dev\/ttyv0/ && /then[[:space:]]*$/ {
        capturing = 1
        block = $0 ORS
        next
    }

    capturing {
        block = block $0 ORS
        if ($0 ~ /^[[:space:]]*fi[[:space:]]*$/) {
            if (block ~ /exec[[:space:]]+start-hyprland/) {
                removed++
            } else {
                printf "%s", block
            }
            capturing = 0
            block = ""
        }
        next
    }

    { print }

    END {
        if (capturing) {
            printf "%s", block
            exit 43
        }
        if (removed != 1)
            exit 42
    }
' "$profile" > "$temporary_profile"; then
    echo ":: Refusing to edit $profile: the expected single ttyv0 block was not found." >&2
    exit 1
fi

if grep -Eq '^[[:space:]]*exec[[:space:]]+start-hyprland([[:space:]]|$)' "$temporary_profile"; then
    echo ":: Refusing to edit $profile: another start-hyprland autostart remains." >&2
    exit 1
fi

if [ "$check_only" = true ]; then
    echo ":: Found the old ttyv0 Hyprland autostart in $profile"
    echo ":: Run again without --check to remove it."
    exit 0
fi

backup_profile="${profile}.pre-bsdrunner-lightdm"
if [ ! -e "$backup_profile" ]; then
    cp -p "$profile" "$backup_profile"
fi
cp -p "$profile" "$temporary_profile.metadata"
trap 'rm -f "$temporary_profile" "$temporary_profile.metadata"' EXIT HUP INT TERM
cp "$temporary_profile" "$temporary_profile.metadata"
mv "$temporary_profile.metadata" "$profile"

echo ":: Removed the ttyv0 Hyprland autostart from $profile"
echo ":: Original retained at $backup_profile"
