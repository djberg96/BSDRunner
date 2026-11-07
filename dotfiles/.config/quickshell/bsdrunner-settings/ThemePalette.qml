import QtQml

QtObject {
    id: root

    property string themeName: "default"
    property string paletteText: ""
    readonly property var palette: resolvePalette(themeName, paletteText)

    function themes() {
        return ({
            "default": {
                "name": "BSDRunner",
                "frameBackground": "#111216",
                "panelBackground": "#181b21",
                "cardBackground": "#20242b",
                "cardHover": "#2a3038",
                "frameBorder": "#5b6470",
                "panelBorder": "#7f8794",
                "primaryText": "#eef2f7",
                "secondaryText": "#cfd6df",
                "mutedText": "#a8b1bd",
                "accent": "#d7e3ea",
                "accentStrong": "#f5fbff",
                "warning": "#ffb86b",
                "danger": "#d08770",
                "success": "#a3be8c"
            },
            "jinteki": {
                "name": "Jinteki",
                "frameBackground": "#12090b",
                "panelBackground": "#1c0f12",
                "cardBackground": "#251013",
                "cardHover": "#341417",
                "frameBorder": "#8f1f34",
                "panelBorder": "#c61f3a",
                "primaryText": "#fff1f3",
                "secondaryText": "#f2cfd5",
                "mutedText": "#cda9b0",
                "accent": "#ff6f83",
                "accentStrong": "#ffd7dd",
                "warning": "#ffb36b",
                "danger": "#ff6b7d",
                "success": "#ffc7cf"
            },
            "haas-bioroid": {
                "name": "Haas-Bioroid",
                "frameBackground": "#0f1418",
                "panelBackground": "#172026",
                "cardBackground": "#1d2830",
                "cardHover": "#283741",
                "frameBorder": "#5f7280",
                "panelBorder": "#8fd3ff",
                "primaryText": "#eef7fc",
                "secondaryText": "#d7e3ea",
                "mutedText": "#aebec9",
                "accent": "#8fd3ff",
                "accentStrong": "#dff6ff",
                "warning": "#ffb86b",
                "danger": "#ff9d7a",
                "success": "#b9e9db"
            },
            "nbn": {
                "name": "NBN",
                "frameBackground": "#171108",
                "panelBackground": "#22180a",
                "cardBackground": "#2a1d0a",
                "cardHover": "#3a280b",
                "frameBorder": "#8d6513",
                "panelBorder": "#f3c316",
                "primaryText": "#fff6dd",
                "secondaryText": "#fff0c7",
                "mutedText": "#d8c18a",
                "accent": "#f3c316",
                "accentStrong": "#ffb347",
                "warning": "#ffb347",
                "danger": "#ff6f5a",
                "success": "#ffd76a"
            },
            "weyland": {
                "name": "Weyland",
                "frameBackground": "#10140f",
                "panelBackground": "#182017",
                "cardBackground": "#212a1d",
                "cardHover": "#2d3827",
                "frameBorder": "#5d8c45",
                "panelBorder": "#b4a14d",
                "primaryText": "#edf3e3",
                "secondaryText": "#dce4d3",
                "mutedText": "#b9c4af",
                "accent": "#5d8c45",
                "accentStrong": "#b4a14d",
                "warning": "#d9a15d",
                "danger": "#d96b2b",
                "success": "#9eb88b"
            }
        })
    }

    function parsePalette(text) {
        var parsed = {}
        var lines = (text || "").split(/\r?\n/)

        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0 || line.charAt(0) === "#")
                continue
            var separator = line.indexOf("=")
            if (separator === -1)
                continue
            parsed[line.slice(0, separator).trim()] = line.slice(separator + 1).trim()
        }
        return parsed
    }

    function clonePalette(source) {
        var copy = {}
        for (var key in source)
            copy[key] = source[key]
        return copy
    }

    function displayName(theme) {
        switch (theme) {
        case "jinteki": return "Jinteki"
        case "haas-bioroid": return "Haas-Bioroid"
        case "nbn": return "NBN"
        case "weyland": return "Weyland"
        default: return "BSDRunner"
        }
    }

    function resolvePalette(theme, text) {
        var available = themes()
        var resolved = clonePalette(available[theme] || available["default"])
        var parsed = parsePalette(text)

        if (parsed.theme_name)
            resolved.name = displayName(parsed.theme_name)
        if (parsed.background)
            resolved.frameBackground = parsed.background
        if (parsed.surface) {
            resolved.panelBackground = parsed.surface
            resolved.cardBackground = parsed.surface
        }
        if (parsed.text) {
            resolved.primaryText = parsed.text
            resolved.secondaryText = parsed.text
        }
        if (parsed.accent)
            resolved.accent = parsed.accent
        if (parsed.accent_strong)
            resolved.accentStrong = parsed.accent_strong
        if (parsed.warning)
            resolved.warning = parsed.warning
        return resolved
    }

    function actionAccent(action) {
        return palette.accent
    }
}
