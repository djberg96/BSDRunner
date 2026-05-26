import Quickshell
import Quickshell.Io
import QtCore
import QtQml

QtObject {
    id: root

    function localPath(value) {
        var text = String(value || "")
        if (text.indexOf("file://") === 0)
            return decodeURIComponent(text.replace(/^file:\/+/, "/"))
        return text
    }

    readonly property string homeDir: localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation))
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
        paletteText: root.paletteFile.text()
    }
}
