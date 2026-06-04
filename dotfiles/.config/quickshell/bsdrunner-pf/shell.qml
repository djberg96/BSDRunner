pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    ThemeLoader {
        id: themeLoader
    }

    readonly property var palette: themeLoader.palette
    property bool loading: false
    property bool runningAction: false
    property bool profileDirty: false
    property string statusTone: "info"
    property string statusMessage: "Loading firewall status..."
    property string actionDetails: ""
    property string snapshotStdoutText: ""
    property string snapshotStderrText: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false
    property string actionStdoutText: ""
    property string actionStderrText: ""
    property int actionExitCode: 0
    property bool actionExited: false
    property bool actionStdoutFinished: false
    property bool actionStderrFinished: false
    property bool logLoading: false
    property bool logFollowing: false
    property bool stoppingLogFollow: false
    property string viewerMode: "logs"
    property string logMessage: "PF logs are loaded on demand."
    property string logText: "Enable blocked-attempt logging, apply the profile, then refresh logs after blocked traffic occurs."
    property int logLineLimit: 200
    property string logStdoutText: ""
    property string logStderrText: ""
    property int logExitCode: 0
    property bool logExited: false
    property bool logStdoutFinished: false
    property bool logStderrFinished: false
    property bool penaltyLoading: false
    property string penaltyMessage: "Load the SSH penalty box to inspect blocked LAN sources."
    property var penaltyEntries: []
    property string selectedPenaltyIp: ""
    property string penaltyStdoutText: ""
    property string penaltyStderrText: ""
    property int penaltyExitCode: 0
    property bool penaltyExited: false
    property bool penaltyStdoutFinished: false
    property bool penaltyStderrFinished: false
    property string activePenaltyAction: "penalty-list"
    property string activePenaltyIp: ""
    property string activeActionId: ""
    property string activeActionArg1: ""
    property string activeActionArg2: ""
    property string activeActionLabel: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property string pfState: "unknown"
    property bool pfRunning: false
    property bool pfAvailable: true
    property bool pfBootEnabled: false
    property bool pflogBootEnabled: false
    property bool sshdBootEnabled: false
    property bool sshdRunning: false
    property bool endlesshInstalled: false
    property bool endlesshBootEnabled: false
    property bool endlesshRunning: false
    property string sshTarpitPort: "22"
    property string sshRealPort: "22222"
    property string configState: "unknown"
    property bool configManaged: false
    property bool configMatchesProfile: false
    property string configChecksum: ""
    property string appliedTimestamp: ""
    property string lastResultTone: "info"
    property string lastResultMessage: "No firewall action has run yet."
    property string lastResultTimestamp: ""
    property var settings: ({
            "allow_outbound": true,
            "block_unsolicited": true,
            "allow_diagnostics": true,
            "allow_ipv6": true,
            "allow_dhcp": true,
            "allow_mdns": true,
            "allow_ssh_lan": false,
            "allow_ssh_tarpit": false,
            "log_blocked": false
        })
    property var rules: []

    function toneColor(tone) {
        switch (tone) {
        case "success":
            return palette.success;
        case "warning":
            return palette.warning;
        case "error":
            return palette.danger;
        default:
            return palette.accent;
        }
    }

    function protectionHeadline() {
        if (pfRunning)
            return "Protected";

        if (configState === "external")
            return "External Config";

        if (configState === "managed")
            return profileDirty ? "Changes Pending" : "Profile Applied";

        switch (pfState) {
        case "stopped":
            return "PF Stopped";
        case "unloaded":
            return "PF Not Loaded";
        case "unavailable":
            return "PF Unavailable";
        default:
            return "Status Unknown";
        }
    }

    function protectionTone() {
        if (pfRunning || (configState === "managed" && !profileDirty))
            return "success";

        if (configState === "external" || profileDirty)
            return "warning";

        return "warning";
    }

    function protectionBadgeText() {
        return protectionTone() === "success" ? "OK" : "!";
    }

    function compactTimestamp(value) {
        if (!value || value.length === 0)
            return "";

        var parts = value.split(" ");
        if (parts.length >= 2)
            return parts[1].replace(/:[0-9][0-9]$/, "");

        return value;
    }

    function statusTimestamp(value) {
        if (!value || value.length === 0)
            return "";

        var parts = value.split(" ");
        if (parts.length >= 2)
            return parts[0] + " " + parts[1].replace(/:[0-9][0-9]$/, "");

        return value;
    }

    function firstNonEmptyLine(value) {
        if (!value || value.length === 0)
            return "";

        var lines = value.split("\n");
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].replace(/^\s+|\s+$/g, "");
            if (line.length > 0)
                return line;
        }

        return "";
    }

    function statusDetailText() {
        if ((statusTone === "error" || lastResultTone === "error") && actionDetails.length > 0)
            return firstNonEmptyLine(actionDetails);

        if (lastResultTimestamp.length > 0)
            return "Updated " + statusTimestamp(lastResultTimestamp);

        return "";
    }

    function profileStatusValue() {
        if (configState === "external")
            return "External";
        if (profileDirty)
            return "Pending";
        return "Current";
    }

    function profileStatusDetail() {
        if (configState === "external")
            return "Adoption needed";

        if (profileDirty)
            return lastResultTimestamp.length > 0 ? "Edited " + compactTimestamp(lastResultTimestamp) : "Edited";

        if (appliedTimestamp.length > 0)
            return "Applied " + compactTimestamp(appliedTimestamp);

        return "Applied";
    }

    function enabledRuleCount() {
        var count = 0;
        for (var i = 0; i < rules.length; i += 1) {
            if (rules[i].enabled)
                count += 1;
        }
        return count;
    }

    function settingValue(key) {
        return !!settings[key];
    }

    function tarpitAvailable() {
        return settingValue("allow_ssh_lan") && endlesshInstalled;
    }

    function tarpitDetailText() {
        if (!settingValue("allow_ssh_lan"))
            return "Enable LAN SSH first.";
        if (!endlesshInstalled)
            return "Install endlessh to enable port 22 tarpitting.";
        if (!settingValue("allow_ssh_tarpit"))
            return "Trap port " + sshTarpitPort + ".";
        return "Trap port " + sshTarpitPort + "; real SSH moves to " + sshRealPort + ".";
    }

    function sshSummaryValue() {
        if (!settingValue("allow_ssh_lan"))
            return "Off";
        if (settingValue("allow_ssh_tarpit"))
            return sshTarpitPort + " -> " + sshRealPort;
        return "LAN only";
    }

    function sshSummaryTone() {
        if (settingValue("allow_ssh_tarpit"))
            return "success";
        if (settingValue("allow_ssh_lan"))
            return "warning";
        return "info";
    }

    function toggleSetting(key, value) {
        if (runningAction || loading)
            return;
        if (key === "allow_ssh_tarpit" && value && !tarpitAvailable())
            return;
        activeActionId = "set";
        activeActionArg1 = key;
        activeActionArg2 = value ? "yes" : "no";
        activeActionLabel = "Updating setting";
        runActionProcess();
    }

    function requestAction(actionId, label, description) {
        if (runningAction)
            return;
        pendingActionId = actionId;
        pendingActionLabel = label;
        pendingActionDescription = description;
    }

    function clearPendingAction() {
        pendingActionId = "";
        pendingActionLabel = "";
        pendingActionDescription = "";
    }

    function confirmPendingAction() {
        if (!pendingActionId)
            return;
        activeActionId = pendingActionId;
        activeActionArg1 = "";
        activeActionArg2 = "";
        activeActionLabel = pendingActionLabel;
        clearPendingAction();
        runActionProcess();
    }

    function runActionProcess() {
        runningAction = true;
        actionDetails = "";
        statusTone = "info";
        statusMessage = activeActionLabel + "...";
        actionStdoutText = "";
        actionStderrText = "";
        actionExitCode = 0;
        actionExited = false;
        actionStdoutFinished = false;
        actionStderrFinished = false;
        actionProcess.running = true;
    }

    function refreshSnapshot() {
        if (snapshotProcess.running)
            return;
        loading = true;
        snapshotStdoutText = "";
        snapshotStderrText = "";
        snapshotExitCode = 0;
        snapshotExited = false;
        snapshotStdoutFinished = false;
        snapshotStderrFinished = false;
        snapshotProcess.running = true;
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return;
        applySnapshot(snapshotStdoutText, snapshotExitCode, snapshotStderrText);
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return;
        applyActionResult(actionStdoutText, actionExitCode, actionStderrText);
    }

    function refreshLogs() {
        if (logProcess.running || logFollowing || runningAction)
            return;
        logLoading = true;
        logMessage = "Loading pflog...";
        logStdoutText = "";
        logStderrText = "";
        logExitCode = 0;
        logExited = false;
        logStdoutFinished = false;
        logStderrFinished = false;
        logProcess.running = true;
    }

    function toggleLogFollow() {
        if (logLoading || runningAction)
            return;
        if (logFollowing) {
            stoppingLogFollow = true;
            followLogProcess.running = false;
            logFollowing = false;
            logMessage = "Live pflog follow stopped.";
            return;
        }

        stoppingLogFollow = false;
        logFollowing = true;
        logText = "";
        logMessage = "Following live pflog0 traffic...";
        followLogProcess.running = true;
    }

    function appendLogLine(line) {
        if (!line || line.length === 0)
            return;
        if (line.indexOf("tcpdump: verbose output suppressed") === 0)
            return;
        var existing = logText.length > 0 ? logText.split("\n") : [];
        existing.push(line);

        while (existing.length > logLineLimit)
            existing.shift();

        logText = existing.join("\n");
    }

    function maybeFinalizeLogs() {
        if (!logExited || !logStdoutFinished || !logStderrFinished)
            return;
        applyLogResult(logStdoutText, logExitCode, logStderrText);
    }

    function openPenaltyBox() {
        if (runningAction)
            return;
        viewerMode = "penalty";
        refreshPenaltyBox();
    }

    function refreshPenaltyBox() {
        if (penaltyProcess.running || runningAction)
            return;
        if (logFollowing)
            toggleLogFollow();
        viewerMode = "penalty";
        activePenaltyAction = "penalty-list";
        activePenaltyIp = "";
        penaltyLoading = true;
        penaltyMessage = "Loading SSH penalty box...";
        penaltyStdoutText = "";
        penaltyStderrText = "";
        penaltyExitCode = 0;
        penaltyExited = false;
        penaltyStdoutFinished = false;
        penaltyStderrFinished = false;
        penaltyProcess.running = true;
    }

    function clearSelectedPenalty() {
        if (selectedPenaltyIp.length === 0 || penaltyProcess.running || runningAction)
            return;
        activePenaltyAction = "penalty-clear";
        activePenaltyIp = selectedPenaltyIp;
        runPenaltyProcess("Clearing " + selectedPenaltyIp + "...");
    }

    function clearAllPenalty() {
        if (penaltyProcess.running || runningAction)
            return;
        activePenaltyAction = "penalty-clear-all";
        activePenaltyIp = "";
        runPenaltyProcess("Clearing all penalty-box entries...");
    }

    function runPenaltyProcess(message) {
        viewerMode = "penalty";
        penaltyLoading = true;
        penaltyMessage = message;
        penaltyStdoutText = "";
        penaltyStderrText = "";
        penaltyExitCode = 0;
        penaltyExited = false;
        penaltyStdoutFinished = false;
        penaltyStderrFinished = false;
        penaltyProcess.running = true;
    }

    function maybeFinalizePenalty() {
        if (!penaltyExited || !penaltyStdoutFinished || !penaltyStderrFinished)
            return;
        applyPenaltyResult(penaltyStdoutText, penaltyExitCode, penaltyStderrText);
    }

    function applySnapshot(text, exitCode, stderrText) {
        loading = false;
        var payload = null;

        try {
            payload = JSON.parse(text || "{}");
        } catch (error) {
            statusTone = "error";
            statusMessage = "The firewall backend returned invalid JSON.";
            actionDetails = stderrText || text || "";
            return;
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error";
            statusMessage = payload.message || stderrText || "Unable to load firewall status.";
            return;
        }

        pfState = payload.pf ? payload.pf.state || "unknown" : "unknown";
        pfRunning = payload.pf ? !!payload.pf.running : false;
        pfAvailable = payload.pf ? payload.pf.available !== false : true;
        pfBootEnabled = payload.boot ? !!payload.boot.pf_enabled : false;
        pflogBootEnabled = payload.boot ? !!payload.boot.pflog_enabled : false;
        sshdBootEnabled = payload.services ? !!payload.services.sshd_enabled : false;
        sshdRunning = payload.services ? !!payload.services.sshd_running : false;
        endlesshInstalled = payload.services ? !!payload.services.endlessh_installed : false;
        endlesshBootEnabled = payload.services ? !!payload.services.endlessh_enabled : false;
        endlesshRunning = payload.services ? !!payload.services.endlessh_running : false;
        sshTarpitPort = payload.services ? payload.services.ssh_tarpit_port || "22" : "22";
        sshRealPort = payload.services ? payload.services.ssh_real_port || "22222" : "22222";
        configState = payload.config ? payload.config.state || "unknown" : "unknown";
        configManaged = payload.config ? !!payload.config.managed : false;
        configMatchesProfile = payload.config ? !!payload.config.matches_profile : false;
        configChecksum = payload.config ? payload.config.checksum || "" : "";
        appliedTimestamp = payload.config ? payload.config.applied_timestamp || "" : "";
        settings = payload.settings || settings;
        rules = payload.rules || [];
        profileDirty = configManaged && !configMatchesProfile;
        lastResultTone = payload.last_result ? payload.last_result.tone || "info" : "info";
        lastResultMessage = payload.last_result ? payload.last_result.message || payload.message : payload.message;
        lastResultTimestamp = payload.last_result ? payload.last_result.timestamp || "" : "";
        statusTone = configState === "external" ? "warning" : lastResultTone;
        statusMessage = configState === "external" ? "External /etc/pf.conf detected. Adopt the BSDRunner profile to let this GUI manage it." : payload.message || "Loaded firewall status.";
    }

    function applyActionResult(text, exitCode, stderrText) {
        runningAction = false;
        var payload = null;

        try {
            payload = JSON.parse(text || "{}");
        } catch (error) {
            payload = null;
        }

        if (payload && payload.ok && exitCode === 0) {
            statusTone = activeActionId === "disable" ? "warning" : "success";
            statusMessage = payload.message || "Firewall action completed.";
            actionDetails = payload.details || "";
            if (activeActionId === "set")
                profileDirty = true;
            if (activeActionId === "apply" || activeActionId === "adopt")
                profileDirty = false;
        } else if (payload) {
            statusTone = "error";
            statusMessage = payload.message || "Firewall action failed.";
            actionDetails = payload.details || stderrText || "";
        } else {
            statusTone = "error";
            statusMessage = "Firewall backend returned invalid JSON.";
            actionDetails = stderrText || text || "";
        }

        activeActionId = "";
        activeActionArg1 = "";
        activeActionArg2 = "";
        activeActionLabel = "";
        refreshSnapshot();
    }

    function applyLogResult(text, exitCode, stderrText) {
        logLoading = false;
        var payload = null;

        try {
            payload = JSON.parse(text || "{}");
        } catch (error) {
            payload = null;
        }

        if (payload && payload.ok && exitCode === 0) {
            logMessage = payload.message || "Loaded recent pflog entries.";
            logText = payload.details && payload.details.length > 0 ? payload.details : "No recent pflog entries.";
        } else if (payload) {
            logMessage = payload.message || "Unable to load pflog.";
            logText = payload.details || stderrText || "";
        } else {
            logMessage = "Firewall backend returned invalid log JSON.";
            logText = stderrText || text || "";
        }
    }

    function applyPenaltyResult(text, exitCode, stderrText) {
        penaltyLoading = false;
        var payload = null;

        try {
            payload = JSON.parse(text || "{}");
        } catch (error) {
            payload = null;
        }

        if (payload && payload.ok && exitCode === 0) {
            penaltyMessage = payload.message || "Loaded SSH penalty box.";
            if (activePenaltyAction === "penalty-list") {
                penaltyEntries = payload.entries || [];
                var selectedStillPresent = false;
                for (var i = 0; i < penaltyEntries.length; i += 1) {
                    if (penaltyEntries[i].ip === selectedPenaltyIp) {
                        selectedStillPresent = true;
                        break;
                    }
                }
                if (!selectedStillPresent)
                    selectedPenaltyIp = "";
            } else {
                selectedPenaltyIp = "";
                refreshPenaltyBox();
            }
        } else if (payload) {
            penaltyMessage = payload.message || "Unable to update the penalty box.";
        } else {
            penaltyMessage = stderrText || text || "Firewall backend returned invalid penalty-box JSON.";
        }

        activePenaltyAction = "penalty-list";
        activePenaltyIp = "";
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh", "snapshot"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotStdoutText = text;
                snapshotProcess.controller.snapshotStdoutFinished = true;
                snapshotProcess.controller.maybeFinalizeSnapshot();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotStderrText = text;
                snapshotProcess.controller.snapshotStderrFinished = true;
                snapshotProcess.controller.maybeFinalizeSnapshot();
            }
        }
        onExited: function (exitCode, exitStatus) {
            snapshotProcess.controller.snapshotExitCode = exitCode;
            snapshotProcess.controller.snapshotExited = true;
            snapshotProcess.controller.maybeFinalizeSnapshot();
        }
    }

    Process {
        id: actionProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh", root.activeActionId, root.activeActionArg1, root.activeActionArg2]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                actionProcess.controller.actionStdoutText = text;
                actionProcess.controller.actionStdoutFinished = true;
                actionProcess.controller.maybeFinalizeAction();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                actionProcess.controller.actionStderrText = text;
                actionProcess.controller.actionStderrFinished = true;
                actionProcess.controller.maybeFinalizeAction();
            }
        }
        onExited: function (exitCode, exitStatus) {
            actionProcess.controller.actionExitCode = exitCode;
            actionProcess.controller.actionExited = true;
            actionProcess.controller.maybeFinalizeAction();
        }
    }

    Process {
        id: logProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh", "logs"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                logProcess.controller.logStdoutText = text;
                logProcess.controller.logStdoutFinished = true;
                logProcess.controller.maybeFinalizeLogs();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                logProcess.controller.logStderrText = text;
                logProcess.controller.logStderrFinished = true;
                logProcess.controller.maybeFinalizeLogs();
            }
        }
        onExited: function (exitCode, exitStatus) {
            logProcess.controller.logExitCode = exitCode;
            logProcess.controller.logExited = true;
            logProcess.controller.maybeFinalizeLogs();
        }
    }

    Process {
        id: penaltyProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh", root.activePenaltyAction, root.activePenaltyIp]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                penaltyProcess.controller.penaltyStdoutText = text;
                penaltyProcess.controller.penaltyStdoutFinished = true;
                penaltyProcess.controller.maybeFinalizePenalty();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                penaltyProcess.controller.penaltyStderrText = text;
                penaltyProcess.controller.penaltyStderrFinished = true;
                penaltyProcess.controller.maybeFinalizePenalty();
            }
        }
        onExited: function (exitCode, exitStatus) {
            penaltyProcess.controller.penaltyExitCode = exitCode;
            penaltyProcess.controller.penaltyExited = true;
            penaltyProcess.controller.maybeFinalizePenalty();
        }
    }

    Process {
        id: followLogProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh", "follow-logs"]
        stdout: SplitParser {
            onRead: function (data) {
                followLogProcess.controller.appendLogLine(data);
            }
        }
        stderr: SplitParser {
            onRead: function (data) {
                followLogProcess.controller.appendLogLine(data);
            }
        }
        onExited: function (exitCode, exitStatus) {
            followLogProcess.controller.logFollowing = false;
            if (followLogProcess.controller.stoppingLogFollow || exitCode === 0) {
                followLogProcess.controller.logMessage = "Live pflog follow stopped.";
            } else {
                followLogProcess.controller.logMessage = "Live pflog follow exited.";
            }
            followLogProcess.controller.stoppingLogFollow = false;
        }
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            if (followLogProcess.running) {
                root.stoppingLogFollow = true;
                followLogProcess.running = false;
            }
            Qt.quit();
        }
    }

    FloatingWindow {
        visible: true
        title: "BSDRunner Firewall"
        minimumSize: Qt.size(1120, 700)
        maximumSize: Qt.size(1120, 700)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.palette.panelBackground

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Row {
                    width: parent.width
                    height: 108
                    spacing: 14

                    Rectangle {
                        width: 330
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.protectionTone())

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 24
                                y: 8
                                color: Qt.alpha(root.toneColor(root.protectionTone()), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.protectionTone())

                                Text {
                                    anchors.centerIn: parent
                                    text: root.protectionBadgeText()
                                    color: root.toneColor(root.protectionTone())
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 70
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.protectionHeadline()
                                    color: root.palette.primaryText
                                    font.pixelSize: 28
                                    minimumPixelSize: 20
                                    fontSizeMode: Text.HorizontalFit
                                    font.bold: true
                                    elide: Text.ElideNone
                                }

                                Text {
                                    width: parent.width
                                    text: "PF Desktop Protection"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    visible: root.configState === "external" || root.configState === "missing"
                                    text: root.configState === "external" ? "External config detected" : "No /etc/pf.conf"
                                    color: root.toneColor(root.configState === "external" ? "warning" : "info")
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 398
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Repeater {
                                model: [
                                    {
                                        "label": "PF at boot",
                                        "value": root.pfBootEnabled ? "Enabled" : "Disabled",
                                        "detail": "",
                                        "tone": root.pfBootEnabled ? "success" : "warning"
                                    },
                                    {
                                        "label": "pflog",
                                        "value": root.pflogBootEnabled ? "Enabled" : "Disabled",
                                        "detail": "",
                                        "tone": root.pflogBootEnabled ? "success" : "warning"
                                    },
                                    {
                                        "label": "Profile",
                                        "value": root.profileStatusValue(),
                                        "detail": root.profileStatusDetail(),
                                        "tone": root.configState === "external" ? "warning" : (root.profileDirty ? "warning" : "info")
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 116
                                    height: 78
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.toneColor(modelData.tone)

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 3

                                        Text {
                                            width: parent.width
                                            text: modelData.label
                                            color: root.palette.mutedText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.value
                                            color: root.toneColor(modelData.tone)
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: modelData.detail.length > 0
                                            width: parent.width
                                            text: modelData.detail
                                            color: root.palette.mutedText
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 330 - 398 - 28
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.statusTone)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            Text {
                                text: "Status"
                                color: root.palette.mutedText
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.statusMessage
                                color: root.palette.primaryText
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                maximumLineCount: root.statusDetailText().length > 0 ? 2 : 3
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: root.statusDetailText().length > 0
                                text: root.statusDetailText()
                                color: root.palette.mutedText
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 46
                    spacing: 10

                    Repeater {
                        model: [
                            {
                                "id": "validate",
                                "label": "Validate",
                                "tone": "info",
                                "text": "Validate the generated BSDRunner firewall profile before loading it."
                            },
                            {
                                "id": root.configState === "external" ? "adopt" : "apply",
                                "label": root.configState === "external" ? "Adopt Profile" : "Apply Profile",
                                "tone": root.configState === "external" ? "warning" : "success",
                                "text": root.configState === "external" ? "Replace the external /etc/pf.conf with the BSDRunner managed profile." : "Validate, install, and reload the generated BSDRunner firewall profile."
                            },
                            {
                                "id": "reload",
                                "label": "Reload",
                                "tone": "info",
                                "text": "Reload the current /etc/pf.conf ruleset."
                            },
                            {
                                "id": "enable",
                                "label": "Enable at Boot",
                                "tone": "success",
                                "text": "Enable PF and pflog services and start them now."
                            },
                            {
                                "id": "disable",
                                "label": "Disable PF Now",
                                "tone": "warning",
                                "text": "Immediately disable PF without deleting /etc/pf.conf."
                            },
                            {
                                "id": "penalty",
                                "label": "Penalty Box",
                                "tone": "warning",
                                "text": "Inspect and clear IP addresses currently in the ssh_abuse table."
                            }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: 150
                            height: 42
                            radius: 8
                            color: actionMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            opacity: root.runningAction ? 0.45 : 1.0
                            border.width: 2
                            border.color: root.toneColor(modelData.tone)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.palette.primaryText
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: actionMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.runningAction
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (modelData.id === "penalty")
                                        root.openPenaltyBox();
                                    else
                                        root.requestAction(modelData.id, modelData.label, modelData.text);
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 108 - 46 - 28
                    spacing: 14

                    Rectangle {
                        width: 420
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            Text {
                                text: "Settings"
                                color: root.palette.primaryText
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    {
                                        "key": "allow_outbound",
                                        "label": "Allow outbound connections",
                                        "detail": "Let apps on this laptop start connections."
                                    },
                                    {
                                        "key": "block_unsolicited",
                                        "label": "Block unsolicited inbound",
                                        "detail": "Reject connections this laptop did not start."
                                    },
                                    {
                                        "key": "allow_diagnostics",
                                        "label": "Allow ping and diagnostics",
                                        "detail": "Keep ping and useful network errors working."
                                    },
                                    {
                                        "key": "allow_ipv6",
                                        "label": "Allow IPv6 essentials",
                                        "detail": "Keep IPv6 neighbor discovery and MTU discovery working."
                                    },
                                    {
                                        "key": "allow_dhcp",
                                        "label": "Allow DHCP address setup",
                                        "detail": "Let the network assign addresses and routes."
                                    },
                                    {
                                        "key": "allow_mdns",
                                        "label": "Allow local discovery",
                                        "detail": "Find local printers, casting devices, and .local names."
                                    },
                                    {
                                        "key": "allow_ssh_lan",
                                        "label": "Allow SSH from local network",
                                        "detail": "Open port 22 only to private IPv4 LAN ranges."
                                    },
                                    {
                                        "key": "allow_ssh_tarpit",
                                        "label": "SSH Tarpit",
                                        "detail": root.tarpitDetailText(),
                                        "enabled": root.tarpitAvailable()
                                    },
                                    {
                                        "key": "log_blocked",
                                        "label": "Log blocked inbound attempts",
                                        "detail": "Write blocked packets to pflog for inspection."
                                    }
                                ]

                                delegate: Rectangle {
                                    id: toggleRow

                                    required property var modelData
                                    readonly property bool checked: root.settingValue(modelData.key)
                                    readonly property bool rowEnabled: modelData.enabled === undefined ? true : modelData.enabled

                                    width: parent.width
                                    height: 40
                                    radius: 8
                                    color: rowEnabled && toggleMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                    opacity: rowEnabled ? 1.0 : 0.48
                                    border.width: 1
                                    border.color: checked ? root.palette.accent : root.palette.frameBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 7
                                        spacing: 10

                                        Rectangle {
                                            width: 42
                                            height: 22
                                            radius: 11
                                            y: 4
                                            color: toggleRow.checked ? root.palette.accent : root.palette.frameBorder

                                            Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 8
                                                x: toggleRow.checked ? 22 : 4
                                                y: 3
                                                color: toggleRow.checked ? root.palette.frameBackground : root.palette.mutedText
                                            }
                                        }

                                        Column {
                                            width: parent.width - 52
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: toggleRow.modelData.label
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: toggleRow.modelData.detail
                                                color: root.palette.mutedText
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: toggleMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !root.runningAction && !root.loading
                                                 && toggleRow.rowEnabled
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.toggleSetting(toggleRow.modelData.key, !toggleRow.checked)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 420 - 14
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                text: "Profile Summary"
                                color: root.palette.primaryText
                                font.pixelSize: 21
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: "Logging is quiet until a rule with log matches traffic. Enable blocked-attempt logging, apply, then refresh or follow."
                                color: root.palette.mutedText
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                id: summaryMetricRow

                                width: parent.width
                                height: 38
                                spacing: 12

                                Repeater {
                                    model: [
                                        {
                                            "id": "enabled",
                                            "label": "Enabled",
                                            "value": root.enabledRuleCount() + " / " + root.rules.length,
                                            "tone": "success"
                                        },
                                        {
                                            "id": "ssh",
                                            "label": "SSH",
                                            "value": root.sshSummaryValue(),
                                            "tone": root.sshSummaryTone()
                                        },
                                        {
                                            "id": "logging",
                                            "label": "Logging",
                                            "value": root.settingValue("log_blocked") ? "On" : "Off",
                                            "tone": root.settingValue("log_blocked") ? "warning" : "info"
                                        }
                                    ]

                                    delegate: Rectangle {
                                        id: summaryMetricCard

                                        required property var modelData
                                        readonly property bool clickable: modelData.id === "logging" && root.settingValue("log_blocked")

                                        width: (summaryMetricRow.width - summaryMetricRow.spacing * 2) / 3
                                        height: 34
                                        radius: 8
                                        color: clickable && summaryMetricMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.toneColor(modelData.tone)

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            anchors.topMargin: 7
                                            anchors.bottomMargin: 7
                                            spacing: 8

                                            Text {
                                                width: 68
                                                height: parent.height
                                                text: modelData.label
                                                color: root.palette.mutedText
                                                font.pixelSize: 10
                                                font.bold: true
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width - 76
                                                height: parent.height
                                                text: modelData.value
                                                color: root.toneColor(modelData.tone)
                                                font.pixelSize: 14
                                                font.bold: true
                                                horizontalAlignment: Text.AlignRight
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: summaryMetricMouse

                                            anchors.fill: parent
                                            hoverEnabled: summaryMetricCard.clickable
                                            enabled: summaryMetricCard.clickable
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.viewerMode = "logs"
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 340
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.viewerMode === "penalty" ? root.palette.warning : (root.settingValue("log_blocked") ? root.palette.warning : root.palette.frameBorder)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Row {
                                        width: parent.width
                                        height: 28
                                        spacing: 10

                                        Text {
                                            width: parent.width - 306
                                            text: root.viewerMode === "penalty" ? "Penalty Box" : "pflog Viewer"
                                            color: root.viewerMode === "penalty" || root.settingValue("log_blocked") ? root.palette.warning : root.palette.primaryText
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: 76
                                            height: 28
                                            radius: 8
                                            color: root.logLoading || root.penaltyLoading ? root.palette.cardBackground : root.palette.cardHover
                                            border.width: 1
                                            border.color: root.palette.frameBorder
                                            opacity: root.logLoading || root.penaltyLoading || root.runningAction ? 0.62 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.logLoading || root.penaltyLoading ? "Loading" : "Refresh"
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !root.logLoading && !root.penaltyLoading && !root.logFollowing && !root.runningAction
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.viewerMode === "penalty" ? root.refreshPenaltyBox() : root.refreshLogs()
                                            }
                                        }

                                        Rectangle {
                                            width: 82
                                            height: 28
                                            visible: root.viewerMode === "logs"
                                            radius: 8
                                            color: root.logFollowing ? Qt.alpha(root.palette.warning, 0.18) : root.palette.cardHover
                                            border.width: 1
                                            border.color: root.logFollowing ? root.palette.warning : root.palette.frameBorder
                                            opacity: root.logLoading || root.runningAction ? 0.62 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.logFollowing ? "Stop" : "Follow"
                                                color: root.logFollowing ? root.palette.warning : root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !root.logLoading && !root.runningAction
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.toggleLogFollow()
                                            }
                                        }

                                        Rectangle {
                                            width: 104
                                            height: 28
                                            visible: root.viewerMode === "penalty"
                                            radius: 8
                                            color: root.selectedPenaltyIp.length > 0 ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.selectedPenaltyIp.length > 0 ? root.palette.warning : root.palette.frameBorder
                                            opacity: root.penaltyLoading || root.runningAction || root.selectedPenaltyIp.length === 0 ? 0.62 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Clear Selected"
                                                color: root.selectedPenaltyIp.length > 0 ? root.palette.warning : root.palette.mutedText
                                                font.pixelSize: 10
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: root.selectedPenaltyIp.length > 0 && !root.penaltyLoading && !root.runningAction
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.clearSelectedPenalty()
                                            }
                                        }

                                        Rectangle {
                                            width: 72
                                            height: 28
                                            visible: root.viewerMode === "penalty"
                                            radius: 8
                                            color: root.penaltyEntries.length > 0 ? Qt.alpha(root.palette.warning, 0.18) : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.penaltyEntries.length > 0 ? root.palette.warning : root.palette.frameBorder
                                            opacity: root.penaltyLoading || root.runningAction || root.penaltyEntries.length === 0 ? 0.62 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Clear All"
                                                color: root.penaltyEntries.length > 0 ? root.palette.warning : root.palette.mutedText
                                                font.pixelSize: 10
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: root.penaltyEntries.length > 0 && !root.penaltyLoading && !root.runningAction
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.clearAllPenalty()
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.viewerMode === "penalty" ? root.penaltyMessage : root.logMessage
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 266
                                        radius: 6
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Flickable {
                                            id: logFlickable

                                            visible: root.viewerMode === "logs"
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            contentWidth: width
                                            contentHeight: logTextContent.paintedHeight
                                            boundsBehavior: Flickable.StopAtBounds
                                            clip: true
                                            interactive: contentHeight > height

                                            onContentHeightChanged: {
                                                if (root.logFollowing)
                                                    contentY = Math.max(0, contentHeight - height);
                                            }

                                            Text {
                                                id: logTextContent

                                                width: logFlickable.width - 12
                                                text: root.logText
                                                color: root.palette.secondaryText
                                                font.family: "monospace"
                                                font.pixelSize: 12
                                                wrapMode: Text.WrapAnywhere
                                            }

                                            Rectangle {
                                                id: logScrollbar

                                                visible: logFlickable.contentHeight > logFlickable.height
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                width: 6
                                                radius: 3
                                                color: root.palette.frameBorder
                                                opacity: 0.32

                                                Rectangle {
                                                    width: parent.width
                                                    radius: 3
                                                    color: root.palette.accent
                                                    opacity: 0.78
                                                    height: Math.max(28, parent.height * (logFlickable.height / Math.max(logFlickable.contentHeight, 1)))
                                                    y: (parent.height - height) * (logFlickable.contentY / Math.max(logFlickable.contentHeight - logFlickable.height, 1))
                                                }
                                            }
                                        }

                                        Flickable {
                                            id: penaltyFlickable

                                            visible: root.viewerMode === "penalty"
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            contentWidth: width
                                            contentHeight: penaltyColumn.height
                                            boundsBehavior: Flickable.StopAtBounds
                                            clip: true
                                            interactive: contentHeight > height

                                            Column {
                                                id: penaltyColumn

                                                width: penaltyFlickable.width - 12
                                                spacing: 7

                                                Text {
                                                    width: parent.width
                                                    visible: root.penaltyEntries.length === 0
                                                    text: "No IP addresses are currently in ssh_abuse."
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 12
                                                    wrapMode: Text.WordWrap
                                                }

                                                Repeater {
                                                    model: root.penaltyEntries

                                                    delegate: Rectangle {
                                                        id: penaltyRow

                                                        required property var modelData
                                                        readonly property bool selected: root.selectedPenaltyIp === modelData.ip

                                                        width: parent.width
                                                        height: 34
                                                        radius: 7
                                                        color: selected ? Qt.alpha(root.palette.warning, 0.18) : root.palette.cardBackground
                                                        border.width: 1
                                                        border.color: selected ? root.palette.warning : root.palette.frameBorder

                                                        Text {
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: 10
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: penaltyRow.modelData.ip
                                                            color: penaltyRow.selected ? root.palette.warning : root.palette.secondaryText
                                                            font.family: "monospace"
                                                            font.pixelSize: 13
                                                            font.bold: penaltyRow.selected
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.selectedPenaltyIp = penaltyRow.modelData.ip
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.pendingActionId.length > 0
                anchors.fill: parent
                color: Qt.alpha("#000000", 0.58)

                Rectangle {
                    width: 460
                    height: 226
                    radius: 8
                    anchors.centerIn: parent
                    color: root.palette.cardBackground
                    border.width: 2
                    border.color: root.toneColor(root.pendingActionId === "disable" || root.pendingActionId === "adopt" ? "warning" : "info")

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Text {
                            width: parent.width
                            text: root.pendingActionLabel
                            color: root.palette.primaryText
                            font.pixelSize: 22
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.pendingActionDescription
                            color: root.palette.secondaryText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "This action can change live firewall behavior."
                            color: root.palette.warning
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            width: parent.width
                            height: 42
                            spacing: 12

                            Rectangle {
                                width: 150
                                height: 40
                                radius: 8
                                color: root.palette.accent
                                border.width: 2
                                border.color: root.palette.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Confirm"
                                    color: root.palette.frameBackground
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.confirmPendingAction()
                                }
                            }

                            Rectangle {
                                width: 150
                                height: 40
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearPendingAction()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
