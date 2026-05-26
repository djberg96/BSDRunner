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

    property var themeFile: FileView {
        path: root.homeDir + "/.config/bsdrunner/current-theme"
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
    }

    property var paletteFile: FileView {
        path: root.palettePath
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
        onPathChanged: this.reload()
    }

    property var themePalette: ThemePalette {
        themeName: root.activeTheme
        paletteText: paletteFile.text()
    }
}
