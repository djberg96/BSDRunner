#!/bin/sh

set -eu

theme="${1:-}"
runner_home="$HOME/.config/bsdrunner"
status_only="no"

if [ "$theme" = "--status" ]; then
    status_only="yes"
    theme=""
fi

if [ -z "$theme" ] && [ -f "$runner_home/current-theme" ]; then
    theme="$(tr -d '\n' < "$runner_home/current-theme")"
fi

[ -n "$theme" ] || theme="default"

palette_file="$runner_home/themes/$theme/palette.conf"
[ -f "$palette_file" ] || palette_file="$runner_home/themes/default/palette.conf"

palette_value() {
    key="$1"
    fallback="$2"
    value="$(awk -F '=' -v key="$key" '
        $1 == key {
            print substr($0, length(key) + 2)
            exit
        }
    ' "$palette_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

theme_name="$(palette_value theme_name "$theme")"
background="$(palette_value background '#101418')"
surface="$(palette_value surface '#1a2128')"
text="$(palette_value text '#d8e1ea')"
accent="$(palette_value accent '#6aa9d8')"
accent_strong="$(palette_value accent_strong '#b7d9f2')"
warning="$(palette_value warning '#ffb86b')"

firefox_homes=""
for candidate in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    if [ -d "$candidate" ]; then
        firefox_homes="${firefox_homes}${firefox_homes:+
}$candidate"
    fi
done

[ -n "$firefox_homes" ] || {
    echo ":: Firefox profile directory not found; skipping Firefox theme"
    exit 0
}

emit_status() {
    echo ":: Firefox theme: $theme_name"
    echo ":: Palette: $palette_file"

    found="no"
    while IFS= read -r firefox_home; do
        [ -n "$firefox_home" ] || continue
        echo ":: Profile root: $firefox_home"
        while IFS= read -r profile_dir; do
            [ "$profile_dir" != "$firefox_home" ] || continue
            if [ ! -f "$profile_dir/prefs.js" ] && [ ! -f "$profile_dir/compatibility.ini" ]; then
                continue
            fi

            found="yes"
            echo ":: Profile: $(basename "$profile_dir")"
            if [ -f "$profile_dir/chrome/userChrome.css" ] && grep -Fq 'bsdrunner-userChrome.css' "$profile_dir/chrome/userChrome.css"; then
                echo "   chrome import: yes"
            else
                echo "   chrome import: no"
            fi
            if [ -f "$profile_dir/chrome/bsdrunner-userChrome.css" ]; then
                echo "   generated chrome: yes"
            else
                echo "   generated chrome: no"
            fi
            if [ -f "$profile_dir/user.js" ] && grep -Fq 'toolkit.legacyUserProfileCustomizations.stylesheets' "$profile_dir/user.js"; then
                echo "   user.js pref: yes"
            else
                echo "   user.js pref: no"
            fi
        done <<EOF
$(find "$firefox_home" -maxdepth 1 -type d | sort)
EOF
    done <<EOF
$firefox_homes
EOF

    if [ "$found" = "no" ]; then
        echo ":: No initialized Firefox profiles found"
    fi
}

if [ "$status_only" = "yes" ]; then
    emit_status
    exit 0
fi

write_user_chrome() {
    target="$1"

    cat > "$target" <<EOF
/*
 * BSDRunner Firefox chrome theme.
 * Generated from $theme_name by bsdrunner-apply-firefox-theme.sh.
 */

:root {
    --bsdrunner-bg: $background;
    --bsdrunner-surface: $surface;
    --bsdrunner-text: $text;
    --bsdrunner-accent: $accent;
    --bsdrunner-accent-strong: $accent_strong;
    --bsdrunner-warning: $warning;

    --lwt-accent-color: var(--bsdrunner-bg) !important;
    --lwt-text-color: var(--bsdrunner-text) !important;
    --lwt-selected-tab-background-color: var(--bsdrunner-surface) !important;
    --toolbar-bgcolor: var(--bsdrunner-surface) !important;
    --toolbar-color: var(--bsdrunner-text) !important;
    --toolbar-field-background-color: var(--bsdrunner-bg) !important;
    --toolbar-field-color: var(--bsdrunner-text) !important;
    --toolbar-field-border-color: var(--bsdrunner-accent) !important;
    --toolbarbutton-hover-background: color-mix(in srgb, var(--bsdrunner-accent) 20%, transparent) !important;
    --toolbarbutton-active-background: color-mix(in srgb, var(--bsdrunner-accent) 34%, transparent) !important;
    --arrowpanel-background: var(--bsdrunner-surface) !important;
    --arrowpanel-color: var(--bsdrunner-text) !important;
    --arrowpanel-border-color: var(--bsdrunner-accent) !important;
    --urlbar-box-bgcolor: color-mix(in srgb, var(--bsdrunner-accent) 18%, var(--bsdrunner-bg)) !important;
    --tabs-navbar-separator-color: var(--bsdrunner-accent) !important;
    --chrome-content-separator-color: var(--bsdrunner-accent) !important;
}

#main-window,
#browser,
#navigator-toolbox {
    background-color: var(--bsdrunner-bg) !important;
    color: var(--bsdrunner-text) !important;
}

#navigator-toolbox {
    border-bottom: 2px solid var(--bsdrunner-accent) !important;
}

#TabsToolbar,
#nav-bar,
#PersonalToolbar {
    background-color: var(--bsdrunner-bg) !important;
    color: var(--bsdrunner-text) !important;
}

#TabsToolbar {
    background:
        linear-gradient(90deg, var(--bsdrunner-accent) 0 4px, transparent 4px),
        var(--bsdrunner-bg) !important;
}

#nav-bar {
    border-top: 1px solid color-mix(in srgb, var(--bsdrunner-accent) 48%, transparent) !important;
}

.tabbrowser-tab .tab-background {
    border-radius: 7px 7px 0 0 !important;
    margin-block: 4px 0 !important;
}

.tabbrowser-tab[selected="true"] .tab-background {
    background-color: var(--bsdrunner-surface) !important;
    border-top: 3px solid var(--bsdrunner-accent-strong) !important;
    outline: 1px solid color-mix(in srgb, var(--bsdrunner-accent) 65%, transparent) !important;
    outline-offset: -1px !important;
}

.tabbrowser-tab:hover .tab-background {
    background-color: color-mix(in srgb, var(--bsdrunner-accent) 18%, var(--bsdrunner-surface)) !important;
}

.tabbrowser-tab:not([selected="true"]) .tab-content {
    color: color-mix(in srgb, var(--bsdrunner-text) 76%, var(--bsdrunner-bg)) !important;
}

#urlbar-background,
#searchbar {
    background-color: var(--bsdrunner-surface) !important;
    border: 2px solid var(--bsdrunner-accent) !important;
    box-shadow: none !important;
}

#urlbar[focused="true"] #urlbar-background {
    border-color: var(--bsdrunner-accent-strong) !important;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--bsdrunner-accent) 60%, transparent) !important;
}

#urlbar-input,
.searchbar-textbox {
    color: var(--bsdrunner-text) !important;
}

#identity-box {
    border-inline-end: 1px solid color-mix(in srgb, var(--bsdrunner-accent) 48%, transparent) !important;
}

toolbarbutton,
.toolbarbutton-icon,
.urlbar-icon,
#identity-icon {
    color: var(--bsdrunner-text) !important;
    fill: currentColor !important;
}

menupopup,
panel {
    --panel-background: var(--bsdrunner-surface) !important;
    --panel-color: var(--bsdrunner-text) !important;
    --panel-border-color: var(--bsdrunner-accent) !important;
}

.browserContainer {
    background-color: var(--bsdrunner-bg) !important;
}
EOF
}

write_user_content() {
    target="$1"

    cat > "$target" <<EOF
/*
 * BSDRunner Firefox content theme.
 * Generated from $theme_name by bsdrunner-apply-firefox-theme.sh.
 */

@-moz-document url("about:home"), url("about:newtab"), url("about:privatebrowsing") {
    :root {
        --newtab-background-color: $background !important;
        --newtab-background-color-secondary: $surface !important;
        --newtab-text-primary-color: $text !important;
        --newtab-primary-action-background: $accent !important;
    }

    body,
    .outer-wrapper {
        background: $background !important;
        color: $text !important;
    }

    .search-wrapper .search-handoff-button,
    .tile,
    .top-site-outer .tile,
    .card-outer,
    .ds-card {
        background-color: $surface !important;
        color: $text !important;
        border-color: $accent !important;
        box-shadow: none !important;
    }

    a,
    .search-handoff-button .fake-textbox,
    .context-menu-button,
    .icon {
        color: $accent_strong !important;
        fill: currentColor !important;
    }
}
EOF
}

ensure_import() {
    css_file="$1"
    import_line="$2"

    if [ -f "$css_file" ] && grep -Fxq "$import_line" "$css_file"; then
        return
    fi

    tmp_file="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-firefox-css.XXXXXX")"
    {
        printf '%s\n' "$import_line"
        [ ! -f "$css_file" ] || cat "$css_file"
    } > "$tmp_file"
    mv "$tmp_file" "$css_file"
}

ensure_user_pref() {
    profile_dir="$1"
    user_js="$profile_dir/user.js"
    pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

    if [ -f "$user_js" ] && grep -Fxq "$pref" "$user_js"; then
        return
    fi

    {
        printf '\n// BSDRunner: enable profile chrome CSS.\n'
        printf '%s\n' "$pref"
    } >> "$user_js"
}

profile_count=0

while IFS= read -r firefox_home; do
    [ -n "$firefox_home" ] || continue
    while IFS= read -r profile_dir; do
        [ "$profile_dir" != "$firefox_home" ] || continue
        if [ ! -f "$profile_dir/prefs.js" ] && [ ! -f "$profile_dir/compatibility.ini" ]; then
            continue
        fi

        profile_count=$((profile_count + 1))
        chrome_dir="$profile_dir/chrome"
        mkdir -p "$chrome_dir"

        write_user_chrome "$chrome_dir/bsdrunner-userChrome.css"
        write_user_content "$chrome_dir/bsdrunner-userContent.css"
        ensure_import "$chrome_dir/userChrome.css" '@import url("bsdrunner-userChrome.css");'
        ensure_import "$chrome_dir/userContent.css" '@import url("bsdrunner-userContent.css");'
        ensure_user_pref "$profile_dir"

        echo ":: Applied BSDRunner Firefox theme to $(basename "$profile_dir")"
    done <<EOF
$(find "$firefox_home" -maxdepth 1 -type d | sort)
EOF
done <<EOF
$firefox_homes
EOF

if [ "$profile_count" -eq 0 ]; then
    echo ":: No initialized Firefox profiles found; skipping Firefox theme"
fi
