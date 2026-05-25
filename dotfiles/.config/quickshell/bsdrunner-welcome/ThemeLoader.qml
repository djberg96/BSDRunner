import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string activeTheme: {
        var text = themeFile.text().trim()
        return text.length > 0 ? text : "default"
    }
    readonly property string palettePath: homeDir + "/.config/bsdrunner/themes/" + activeTheme + "/palette.conf"
    readonly property var palette: themePalette.palette

    function actionAccent(action) {
        return themePalette.actionAccent(action)
    }

    FileView {
        id: themeFile
        path: root.homeDir + "/.config/bsdrunner/current-theme"
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
    }

    FileView {
        id: paletteFile
        path: root.palettePath
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
        onPathChanged: this.reload()
    }

    ThemePalette {
        id: themePalette
        themeName: root.activeTheme
        paletteText: paletteFile.text()
    }
}
