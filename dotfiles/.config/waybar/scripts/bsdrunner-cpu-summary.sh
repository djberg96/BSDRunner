#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

if [ "${BSDRUNNER_CPU_VMSTAT_JSON+x}" = "x" ]; then
    snapshot="$BSDRUNNER_CPU_VMSTAT_JSON"
else
    snapshot="$(vmstat --libxo json -P -w 0.2 -c 2 2>/dev/null || true)"
fi

cpu_data="$(printf '%s\n' "$snapshot" | jq -r '
    [.vmstat.cpu[]? | {
        core: ((.name | tonumber) + 1),
        usage: ([0, (100 - .idle), 100] | sort | .[1])
    }] as $cores |
    select($cores | length > 0) |
    (($cores | map(.usage) | add / length) | round),
    ($cores[] | "Core \(.core): \(.usage)%")
' 2>/dev/null || true)"

overall_usage="$(printf '%s\n' "$cpu_data" | sed -n '1p')"
core_tooltip="$(printf '%s\n' "$cpu_data" | sed '1d')"
case "$overall_usage" in
    ''|*[!0-9]*) overall_usage="--"; percentage=0 ;;
    *) percentage="$overall_usage" ;;
esac
[ -n "$core_tooltip" ] || core_tooltip="Per-core CPU usage unavailable"

if [ "${BSDRUNNER_CPU_TEMPERATURES+x}" = "x" ]; then
    temperatures="$BSDRUNNER_CPU_TEMPERATURES"
else
    temperatures="$(sysctl hw.acpi.thermal 2>/dev/null | awk -F ': ' '
        /\.temperature:/ { sub(/[[:space:]]*C$/, "", $2); print $2 }
    ')"
    if [ -z "$temperatures" ]; then
        temperatures="$(sysctl dev.cpu 2>/dev/null | awk -F ': ' '
            /\.temperature:/ { sub(/[[:space:]]*C$/, "", $2); print $2 }
        ')"
    fi
fi

temperature="$(printf '%s\n' "$temperatures" | awk '
    /^[0-9]+([.][0-9]+)?$/ {
        if (!found || $1 > hottest) hottest = $1
        found = 1
    }
    END { if (found) printf "%.1f\n", hottest }
')"

if [ -z "$temperature" ]; then
    temperature_label="--"
    temperature_description="unavailable"
    temperature_class="unknown"
elif awk -v value="$temperature" 'BEGIN { exit !(value >= 85) }'; then
    temperature_label="${temperature}°C"
    temperature_description="hot"
    temperature_class="hot"
elif awk -v value="$temperature" 'BEGIN { exit !(value >= 70) }'; then
    temperature_label="${temperature}°C"
    temperature_description="warm"
    temperature_class="warm"
else
    temperature_label="${temperature}°C"
    temperature_description="cool"
    temperature_class="cool"
fi

jq -cn \
    --arg text " ${overall_usage}%" \
    --arg tooltip "$(printf '%s\n%s\n%s' "$core_tooltip" \
        "──────────────────────────────" \
        "CPU temperature: $temperature_label ($temperature_description)")" \
    --arg class "$temperature_class" \
    --argjson percentage "$percentage" \
    '{text: $text, tooltip: $tooltip, percentage: $percentage, class: $class}'
