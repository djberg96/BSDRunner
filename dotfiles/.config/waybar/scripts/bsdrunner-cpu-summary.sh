#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

if [ "${BSDRUNNER_CPU_TIMES_PREVIOUS+x}" = "x" ] &&
    [ "${BSDRUNNER_CPU_TIMES_CURRENT+x}" = "x" ]; then
    previous_times="$BSDRUNNER_CPU_TIMES_PREVIOUS"
    current_times="$BSDRUNNER_CPU_TIMES_CURRENT"
else
    state_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
    state_file="$state_dir/bsdrunner-waybar-cpu-summary-$(id -u).state"
    current_times="$(sysctl -n kern.cp_times 2>/dev/null || true)"
    previous_times="$(cat "$state_file" 2>/dev/null || true)"

    if [ -z "$previous_times" ]; then
        previous_times="$current_times"
        sleep 0.2
        current_times="$(sysctl -n kern.cp_times 2>/dev/null || true)"
    fi

    umask 077
    state_temp="$state_file.$$"
    if printf '%s\n' "$current_times" > "$state_temp" 2>/dev/null; then
        mv -f "$state_temp" "$state_file"
    else
        rm -f "$state_temp"
    fi
fi

cpu_data="$(awk -v previous="$previous_times" -v current="$current_times" '
    BEGIN {
        before_count = split(previous, before, " ")
        after_count = split(current, after, " ")
        if (before_count != after_count || after_count < 5 || after_count % 5 != 0) exit

        for (start = 1; start <= after_count; start += 5) {
            total = 0
            for (field = start; field < start + 5; field++) {
                delta = after[field] - before[field]
                if (delta < 0) exit
                total += delta
            }
            idle = after[start + 4] - before[start + 4]
            if (total <= 0) exit
            usage[++cores] = int((((total - idle) * 100) / total) + 0.5)
            combined_total += total
            combined_idle += idle
        }

        print int((((combined_total - combined_idle) * 100) / combined_total) + 0.5)
        for (core = 1; core <= cores; core++) print "Core " core ": " usage[core] "%"
    }
')"

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
