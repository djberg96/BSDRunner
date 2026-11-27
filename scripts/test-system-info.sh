#!/bin/sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
snapshot="$(sh "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-system-info.sh")"
printf '%s\n' "$snapshot" | jq -e '
    type == "array" and length > 0 and
    all(.[]; (.label | type == "string" and length > 0) and (.value | type == "string" and length > 0)) and
    any(.[]; .label == "Operating system") and any(.[]; .label == "Architecture")
' >/dev/null
if [ "$(uname -s)" = FreeBSD ]; then
    boot="$(sysctl -n kern.boottime | awk -F '[, =]+' '$2 == "sec" {print $3}')"
    now="$(date +%s)"
    expected_days=$(( (now - boot) / 86400 ))
    actual_days="$(printf '%s\n' "$snapshot" | jq -r '.[] | select(.label == "Uptime") | .value' | awk '{print $1}')"
    [ "$actual_days" = "$expected_days" ] || {
        printf 'Uptime does not match the system boot time.\n' >&2
        exit 1
    }
fi
helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-system-info.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-system-info-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
cat > "$test_root/fastfetch" <<'MOCK'
#!/bin/sh
[ "$1" = -c ] && [ "$2" = none ] || exit 2
cat <<'JSON'
[
  {"type":"OS","error":"unavailable"},
  {"type":"CPU","result":{"cpu":"Fixture CPU", "cores":{"logical":4}}},
  {"type":"Memory","result":{"total":8589934592,"used":2147483648}},
  {"type":"Host","result":{"version":"Fixture Computer","serial":"SECRET-SERIAL"}},
  {"type":"Uptime","result":{"uptime":61000}}
]
JSON
MOCK
chmod 755 "$test_root/fastfetch"
fixture_snapshot="$(BSDRUNNER_FASTFETCH_BIN="$test_root/fastfetch" sh "$helper")"
printf '%s\n' "$fixture_snapshot" | jq -e '
    any(.[]; .label == "Processor" and .value == "Fixture CPU (4 logical CPUs)") and
    any(.[]; .label == "Memory" and .value == "2 GiB used of 8 GiB") and
    any(.[]; .label == "Computer" and .value == "Fixture Computer") and
    any(.[]; .label == "Uptime" and .value == "0 days, 0 hours, 1 minute") and
    any(.[]; .label == "Operating system" and (.value | length > 0)) and
    all(.[]; (.value | contains("SECRET-SERIAL") | not))
' >/dev/null || { printf 'Fastfetch fields or per-field fallback failed.\n' >&2; exit 1; }

native="$(BSDRUNNER_FASTFETCH_BIN="$test_root/missing" sh "$helper")"
cat > "$test_root/fastfetch" <<'MOCK'
#!/bin/sh
printf 'invalid json\n'
MOCK
invalid="$(BSDRUNNER_FASTFETCH_BIN="$test_root/fastfetch" sh "$helper")"
native_cpu="$(printf '%s\n' "$native" | jq -r '.[] | select(.label == "Processor") | .value')"
invalid_cpu="$(printf '%s\n' "$invalid" | jq -r '.[] | select(.label == "Processor") | .value')"
[ "$native_cpu" = "$invalid_cpu" ] || { printf 'Invalid Fastfetch output did not fall back.\n' >&2; exit 1; }
printf '%s\n' "$invalid" | jq -e 'type == "array" and length > 0' >/dev/null

printf 'System info snapshot tests passed.\n'
