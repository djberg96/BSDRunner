#!/bin/sh

set -eu

profile="${HOME}/.profile"
zprofile=""
check_only=false
found_any=false

usage() {
    cat <<'EOF'
Usage: bsdrunner-disable-console-autostart.sh [--check] [--profile FILE] [--zprofile FILE]

Removes recognized BSDRunner console autostart blocks from the Bourne/Bash and
Zsh login profiles. Originals are retained with a .pre-bsdrunner-ly suffix.
EOF
}

has_console_autostart() {
    candidate="$1"
    [ -f "$candidate" ] || return 1
    grep -Eq 'BSDRUNNER GREETER AUTOSTART|bsdrunner-login-dispatch\.sh|^[[:space:]]*exec[[:space:]]+start-hyprland([[:space:]]|$)' "$candidate"
}

migrate_file() {
    source_file="$1"
    [ -f "$source_file" ] || return 0
    has_console_autostart "$source_file" || return 0
    found_any=true

    source_dir="$(CDPATH= cd -- "$(dirname -- "$source_file")" && pwd)"
    temporary_file="$(mktemp "$source_dir/.bsdrunner-profile.XXXXXX")"

    if ! awk '
        BEGIN {
            in_greeter = 0
            in_tty = 0
            greeter_count = 0
            tty_count = 0
            tty_block = ""
        }

        /^# >>> BSDRUNNER GREETER AUTOSTART >>>$/ {
            if (in_greeter || in_tty)
                exit 44
            in_greeter = 1
            greeter_count++
            next
        }

        in_greeter {
            if ($0 == "# <<< BSDRUNNER GREETER AUTOSTART <<<")
                in_greeter = 0
            next
        }

        !in_tty && /\/dev\/ttyv0/ && /then[[:space:]]*$/ {
            in_tty = 1
            tty_block = $0 ORS
            next
        }

        in_tty {
            tty_block = tty_block $0 ORS
            if ($0 ~ /^[[:space:]]*fi[[:space:]]*$/) {
                if (tty_block ~ /exec[[:space:]]+start-hyprland/)
                    tty_count++
                else
                    printf "%s", tty_block
                in_tty = 0
                tty_block = ""
            }
            next
        }

        { print }

        END {
            if (in_greeter || in_tty)
                exit 43
            if (greeter_count > 1 || tty_count > 1)
                exit 44
            if (greeter_count + tty_count == 0)
                exit 42
        }
    ' "$source_file" > "$temporary_file"; then
        rm -f "$temporary_file"
        echo ":: Refusing to edit $source_file: recognized autostart blocks are malformed." >&2
        exit 1
    fi

    if has_console_autostart "$temporary_file"; then
        rm -f "$temporary_file"
        echo ":: Refusing to edit $source_file: an unrecognized console autostart remains." >&2
        exit 1
    fi

    if [ "$check_only" = true ]; then
        rm -f "$temporary_file"
        echo ":: Found recognized BSDRunner console autostart in $source_file"
        return 0
    fi

    backup_file="${source_file}.pre-bsdrunner-ly"
    if [ ! -e "$backup_file" ]; then
        cp -p "$source_file" "$backup_file"
    fi
    metadata_file="${temporary_file}.metadata"
    cp -p "$source_file" "$metadata_file"
    cp "$temporary_file" "$metadata_file"
    mv "$metadata_file" "$source_file"
    rm -f "$temporary_file"

    echo ":: Removed recognized console autostart from $source_file"
    echo ":: Original retained at $backup_file"
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
        --zprofile)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                exit 1
            }
            zprofile="$2"
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

if [ -z "$zprofile" ]; then
    zprofile="$(dirname -- "$profile")/.zprofile"
fi

migrate_file "$profile"
migrate_file "$zprofile"

if [ "$found_any" = false ]; then
    echo ":: No recognized BSDRunner console autostart is present."
elif [ "$check_only" = true ]; then
    echo ":: Run again without --check to remove the recognized blocks."
fi
