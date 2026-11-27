#!/bin/sh
set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

# Each probe is optional: missing hardware or a non-Hyprland session should
# leave the other information usable.
os="$(freebsd-version -u 2>/dev/null || uname -r 2>/dev/null || true)"
os_name="$(uname -s 2>/dev/null || true)"
[ -z "$os" ] || os="$os_name $os"
architecture="$(uname -m 2>/dev/null || true)"
kernel="$(uname -r 2>/dev/null || true)"
host="$(hostname -s 2>/dev/null || true)"
model="$(kenv -q smbios.system.version 2>/dev/null || true)"
cpu="$(sysctl -n hw.model 2>/dev/null || true)"
cores="$(sysctl -n hw.ncpu 2>/dev/null || true)"
case "$cores" in ''|*[!0-9]*) ;; *) [ -z "$cpu" ] || cpu="$cpu ($cores logical CPUs)" ;; esac
memory="$(sysctl -n hw.physmem 2>/dev/null | awk '/^[0-9]+$/ {printf "%.1f GiB", $1 / 1073741824}' || true)"
boot="$(sysctl -n kern.boottime 2>/dev/null | awk -F '[, =]+' '$2 == "sec" {print $3}' || true)"
now="$(date +%s 2>/dev/null || true)"
uptime_text="$(awk -v boot="$boot" -v now="$now" 'BEGIN {if (boot > 0 && now >= boot) {s = now - boot; d = int(s / 86400); h = int((s % 86400) / 3600); m = int((s % 3600) / 60); printf "%d day%s, %d hour%s, %d minute%s", d, (d == 1 ? "" : "s"), h, (h == 1 ? "" : "s"), m, (m == 1 ? "" : "s")}}')"
gpu="$(pciconf -lv 2>/dev/null | awk -F "'" '/^[^[:space:]]+@pci/ {if (display) exit; if ($0 ~ /class=0x03/) display=1; next} display && /device[[:space:]]*=/ {print $2; exit}' || true)"
displays="$(hyprctl -j monitors 2>/dev/null | jq -r '[.[] | "\(.name): \(.width) × \(.height) @ \(.refreshRate | round) Hz"] | join(", ")' 2>/dev/null || true)"
storage="$(df -k / 2>/dev/null | awk 'NR == 2 && $2 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ {printf "%.1f GiB available of %.1f GiB", $4 / 1048576, $2 / 1048576}' || true)"
session="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"

native_snapshot="$(jq -nc \
    --arg os "$os" --arg kernel "$kernel" --arg arch "$architecture" \
    --arg host "$host" --arg model "$model" --arg cpu "$cpu" \
    --arg memory "$memory" --arg gpu "$gpu" --arg displays "$displays" \
    --arg storage "$storage" --arg uptime "$uptime_text" --arg session "$session" \
    '[{label:"Operating system",value:$os},{label:"Kernel",value:$kernel},
      {label:"Architecture",value:$arch},{label:"Computer",value:$model},
      {label:"Host name",value:$host},{label:"Processor",value:$cpu},
      {label:"Graphics",value:$gpu},{label:"Memory",value:$memory},
      {label:"Root storage",value:$storage},{label:"Displays",value:$displays},
      {label:"Desktop",value:$session},{label:"Uptime",value:$uptime}]
     | map(select(.value != ""))')"

fastfetch_bin="${BSDRUNNER_FASTFETCH_BIN:-fastfetch}"
if command -v "$fastfetch_bin" >/dev/null 2>&1 &&
    fastfetch_json="$("$fastfetch_bin" -c none --structure OS:Host:Kernel:Uptime:CPU:GPU:Memory:Display:Disk:WM --format json --pipe true 2>/dev/null)" &&
    fastfetch_snapshot="$(printf '%s\n' "$fastfetch_json" | jq -ec --argjson fallback "$native_snapshot" '
        if type != "array" then error("Invalid Fastfetch response") else . end |
        def findmod($name): [ .[] | select(type == "object" and .type == $name and .result != null) | .result ][0];
        def gib: ((. / 1073741824 * 10 | round) / 10 | tostring) + " GiB";
        def elapsed:
            (./1000 | floor) as $s |
            ($s / 86400 | floor) as $d | (($s % 86400) / 3600 | floor) as $h | (($s % 3600) / 60 | floor) as $m |
            "\($d) day\(if $d == 1 then "" else "s" end), \($h) hour\(if $h == 1 then "" else "s" end), \($m) minute\(if $m == 1 then "" else "s" end)";
        def textvalue: if type == "string" and length > 0 then . else null end;
        [
            {label:"Operating system", value:(try (findmod("OS") | (.prettyName // .name) | textvalue) catch null)},
            {label:"Kernel", value:(try (findmod("Kernel").release | textvalue) catch null)},
            {label:"Architecture", value:(try (findmod("Kernel").architecture | textvalue) catch null)},
            {label:"Computer", value:(try (findmod("Host") | (.version // .family // .name) | textvalue) catch null)},
            {label:"Processor", value:(try (findmod("CPU") | (.cpu | textvalue) as $name | if $name == null then null elif (.cores.logical | type) == "number" and .cores.logical > 0 then "\($name) (\(.cores.logical) logical CPUs)" else $name end) catch null)},
            {label:"Graphics", value:(try ([findmod("GPU")[] | [(.vendor | textvalue), (.name | textvalue)] | map(select(. != null)) | join(" ") | select(length > 0)] | join(", ") | textvalue) catch null)},
            {label:"Memory", value:(try (findmod("Memory") | if (.total | type) == "number" and .total > 0 then if (.used | type) == "number" and .used >= 0 and .used <= .total then "\(.used | gib) used of \(.total | gib)" else (.total | gib) end else null end) catch null)},
            {label:"Root storage", value:(try ([findmod("Disk")[] | select(.mountpoint == "/")][0].bytes | if (.free | type) == "number" and (.total | type) == "number" and .total > 0 then "\(.free | gib) free of \(.total | gib)" else null end) catch null)},
            {label:"Displays", value:(try ([findmod("Display")[] | select((.output.width | type) == "number" and (.output.height | type) == "number" and .output.width > 0 and .output.height > 0) | "\((.name | textvalue) // "Display"): \(.output.width) × \(.output.height)" + (if (.output.refreshRate | type) == "number" and .output.refreshRate > 0 then " @ \(.output.refreshRate | round) Hz" else "" end)] | join(", ") | textvalue) catch null)},
            {label:"Desktop", value:(try (findmod("WM").prettyName | textvalue) catch null)},
            {label:"Uptime", value:(try (findmod("Uptime").uptime | if type == "number" and . >= 0 then elapsed else null end) catch null)}
        ] | map(select(.value != null)) as $fast |
        reduce $fast[] as $item ($fallback; if any(.[]; .label == $item.label) then map(if .label == $item.label then $item else . end) else . + [$item] end)
    ' 2>/dev/null)"; then
    printf '%s\n' "$fastfetch_snapshot"
else
    printf '%s\n' "$native_snapshot"
fi
