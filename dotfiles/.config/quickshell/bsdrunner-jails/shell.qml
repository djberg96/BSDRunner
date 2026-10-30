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
    property bool beginnerMapVisible: true
    property bool createPreviewVisible: false
    property bool createPreviewLoading: false
    property int wizardStep: 0
    property bool demoMode: false
    property bool creationRunning: false
    property bool storageSetupRunning: false
    property string storageSetupStage: "idle"
    property string storageSetupMessage: ""
    property string storageSetupDetails: ""
    property string storageConfirmation: ""
    property string selectedStoragePool: ""
    property var storageInfo: ({"configured": false, "initialized": false, "prefix": "/usr/local/bastille", "zfs_pool": "", "zfs_prefix": "bastille", "target_dataset": "", "pools": []})
    property string storageStdoutText: ""
    property string storageStderrText: ""
    property int storageExitCode: 0
    property bool storageExited: false
    property bool storageStdoutFinished: false
    property bool storageStderrFinished: false
    property bool networkSetupRunning: false
    property string networkSetupStage: "idle"
    property string networkSetupMessage: ""
    property string networkSetupDetails: ""
    property string networkConfirmation: ""
    property var networkInfo: ({"ready": false, "loopback_ready": false, "pf_running": false, "nat_ready": false, "rdr_anchor_ready": false, "filter_anchor_ready": false, "loopback_interface": "bastille0", "external_interface": "", "recommended_address": "10.0.0.20/24"})
    property string networkStdoutText: ""
    property string networkStderrText: ""
    property int networkExitCode: 0
    property bool networkExited: false
    property bool networkStdoutFinished: false
    property bool networkStderrFinished: false
    property string creationStage: "idle"
    property string creationMessage: ""
    property string creationError: ""
    property string creationConfirmation: ""
    property bool creationBootstrapped: false
    property string provisionAction: ""
    property string provisionNextAction: ""
    property string provisionStdoutText: ""
    property string provisionStderrText: ""
    property int provisionExitCode: 0
    property bool provisionExited: false
    property bool provisionStdoutFinished: false
    property bool provisionStderrFinished: false
    property string statusTone: "info"
    property string statusMessage: "Loading jail status..."
    property string actionDetails: ""
    property string activeActionId: ""
    property string activeActionName: ""
    property string activeActionBackend: ""
    property string activeActionPolicy: ""
    property string activeActionProtocol: ""
    property string activeActionHostPort: ""
    property string activeActionJailPort: ""
    property string activeActionService: ""
    property string activeActionServiceVerb: ""
    property string activeActionLabel: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property string selectedJailName: ""
    property string selectedJailBackend: ""
    property string selectedBeginnerTopic: "storage"
    property var runningJails: []
    property var configuredJails: []
    property var bastilleJails: []
    property var outboundPolicies: []
    property var portForwards: []
    property var simpleServices: []
    property var tools: ({})
    property var services: ({})
    property var bastilleReleases: []
    property bool bastilleSetup: false
    property string hostRelease: ""
    property string lastResultTone: "info"
    property string lastResultMessage: "No jail action has run yet."
    property string lastResultTimestamp: ""
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
    property string previewName: "web"
    property string previewRelease: "15.0-RELEASE"
    property bool previewReleaseCustomized: false
    property bool previewReleaseCustom: false
    property bool releaseMenuOpen: false
    property string previewJailType: "thick"
    property string previewOutboundPolicy: "internet-only"
    property string forwardProtocol: "tcp"
    property string forwardHostPort: "8080"
    property string forwardJailPort: "80"
    property string previewAddress: "10.0.0.20/24"
    property bool previewAddressCustomized: false
    property bool previewAutostart: true
    property var previewPayload: null
    property string previewError: ""
    property string previewStdoutText: ""
    property string previewStderrText: ""
    property int previewExitCode: 0
    property bool previewExited: false
    property bool previewStdoutFinished: false
    property bool previewStderrFinished: false

    readonly property var jails: mergedJails()
    readonly property var selectedJail: findJail(selectedJailName, selectedJailBackend)
    readonly property var selectedSimpleService: simpleServiceFor(selectedJail, "nginx")
    readonly property var selectedServiceForwards: serviceForwardsFor(selectedJail, selectedSimpleService)
    readonly property bool wizardBusy: createPreviewLoading || creationRunning || storageSetupRunning || networkSetupRunning
    readonly property var wizardSteps: ["Storage", "Userland", "Network", "Config", "Lifecycle"]
    readonly property var outboundPolicyChoices: [
        {"id": "internet-only", "label": "Internet only", "detail": "DNS + public • Recommended"},
        {"id": "lan", "label": "LAN + Internet", "detail": "Private and public networks"},
        {"id": "none", "label": "No outbound", "detail": "Block new connections"}
    ]
    readonly property int wizardCaptionFontSize: 12
    readonly property int wizardBodyFontSize: 13
    readonly property int wizardControlFontSize: 14
    readonly property int wizardHeadingFontSize: 16
    readonly property int wizardPlanFontSize: 15
    readonly property var beginnerTopics: [
        {
            "id": "storage",
            "title": "1. Storage",
            "body": "A jail needs a filesystem root. ZFS datasets are the cleanest place to keep those roots.",
            "detail": "Start by deciding where jail roots live. Bastille conventionally uses POOL/bastille, then creates child datasets for releases, jails, cache, backups, and templates."
        },
        {
            "id": "userland",
            "title": "2. Userland",
            "body": "FreeBSD does not create a full system tree by itself. You fetch or extract a release first.",
            "detail": "The jail shares the host kernel, but it still needs its own /bin, /etc, /usr, and packages. Bastille can bootstrap this; native jails usually start from a fetched base.txz or an existing template."
        },
        {
            "id": "network",
            "title": "3. Network",
            "body": "A private jail address needs a loopback interface and PF NAT before it can reach the network.",
            "detail": "BSDRunner keeps the pieces separate: Bastille owns its loopback interface and dynamic jail table, while the managed PF profile supplies NAT and Bastille's redirect/filter anchors."
        },
        {
            "id": "config",
            "title": "4. Config",
            "body": "jail.conf gives the jail a name, path, hostname, network address, and startup behavior.",
            "detail": "The config is the contract between the host and the jail. It points at the root path, names the jail, chooses networking, controls devfs, and decides whether service jail start should include it."
        },
        {
            "id": "lifecycle",
            "title": "5. Lifecycle",
            "body": "Once configured, start, stop, restart, and console are the everyday operations.",
            "detail": "After setup, jails feel like small service machines. Start boots the jail, console gets you inside, restart applies many config changes, and stop shuts the contained userland down."
        }
    ]
    readonly property var selectedBeginner: findBeginnerTopic(selectedBeginnerTopic)

    function toneColor(tone) {
        switch (tone) {
        case "success":
            return palette.success
        case "warning":
            return palette.warning
        case "error":
            return palette.danger
        default:
            return palette.accent
        }
    }

    function mergedJails() {
        var merged = []
        var seen = {}
        addJails(merged, seen, bastilleJails || [])
        addJails(merged, seen, runningJails || [])
        addJails(merged, seen, configuredJails || [])
        return merged
    }

    function addJails(target, seen, source) {
        for (var i = 0; i < source.length; i += 1) {
            var jail = source[i]
            var identity = jail.name || jail.hostname || jail.path || jail.jid
            var key = identity ? "jail:" + identity : ""
            if (!key || seen[key])
                continue
            seen[key] = true
            target.push(jail)
        }
    }

    function findJail(name, backend) {
        var all = jails
        for (var i = 0; i < all.length; i += 1) {
            if (all[i].name === name && all[i].backend === backend)
                return all[i]
        }
        return null
    }

    function findBeginnerTopic(topicId) {
        for (var i = 0; i < beginnerTopics.length; i += 1) {
            if (beginnerTopics[i].id === topicId)
                return beginnerTopics[i]
        }
        return beginnerTopics.length > 0 ? beginnerTopics[0] : null
    }

    function selectJail(jail) {
        selectedJailName = jail ? jail.name || "" : ""
        selectedJailBackend = jail ? jail.backend || "native" : ""
        clearPendingAction()
    }

    function headline() {
        if (!tools.jls && !tools.bastille)
            return "No Jail Tools"
        if (jails.length === 0)
            return "No Jails Yet"
        if (runningCount() > 0)
            return runningCount() + " Running"
        return "Jails Ready"
    }

    function headlineTone() {
        if (!tools.jls && !tools.bastille)
            return "error"
        if (runningCount() > 0)
            return "success"
        if (jails.length > 0)
            return "warning"
        return "info"
    }

    function runningCount() {
        var count = 0
        for (var i = 0; i < jails.length; i += 1) {
            if ((jails[i].state || "").toLowerCase() === "running")
                count += 1
        }
        return count
    }

    function backendLabel(jail) {
        if (!jail)
            return "No backend"
        return jail.backend === "bastille" ? "Bastille" : "Native jail"
    }

    function stateTone(jail) {
        if (!jail)
            return "info"
        var state = (jail.state || "").toLowerCase()
        if (state === "running")
            return "success"
        if (state === "configured" || state === "stopped")
            return "warning"
        return "info"
    }

    function compactTimestamp(value) {
        if (!value || value.length === 0)
            return ""
        var parts = value.split(" ")
        if (parts.length >= 2)
            return parts[1].replace(/:[0-9][0-9]$/, "")
        return value
    }

    function firstNonEmptyLine(value) {
        if (!value || value.length === 0)
            return ""
        var lines = value.split("\n")
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].replace(/^\s+|\s+$/g, "")
            if (line.length > 0)
                return line
        }
        return ""
    }

    function normalizedHostRelease(value) {
        var release = (value || "").replace(/^\s+|\s+$/g, "")
        if (!/^[0-9]+\.[0-9]+-RELEASE(-p[0-9]+)?$/.test(release))
            return ""
        return release.replace(/-p[0-9]+$/, "")
    }

    function defaultPreviewRelease() {
        var hostDefault = normalizedHostRelease(hostRelease)
        if (hostDefault.length > 0)
            return hostDefault
        if (bastilleReleases.length > 0)
            return bastilleReleases[bastilleReleases.length - 1]
        return "15.0-RELEASE"
    }

    function releaseIsBootstrapped(value) {
        for (var i = 0; i < bastilleReleases.length; i += 1) {
            if (bastilleReleases[i] === value)
                return true
        }
        return false
    }

    function releaseChoices() {
        var choices = []
        var seen = {}
        var hostDefault = normalizedHostRelease(hostRelease)
        if (hostDefault.length > 0) {
            choices.push({"value": hostDefault, "label": hostDefault, "detail": "Host match • Recommended", "custom": false})
            seen[hostDefault] = true
        }
        for (var i = bastilleReleases.length - 1; i >= 0; i -= 1) {
            var release = bastilleReleases[i]
            if (!release || seen[release])
                continue
            choices.push({"value": release, "label": release, "detail": "Bootstrapped • Ready", "custom": false})
            seen[release] = true
        }
        choices.push({"value": "", "label": "Custom release…", "detail": "Enter another compatible FreeBSD release", "custom": true})
        return choices
    }

    function releaseSelectionDetail() {
        if (previewReleaseCustom)
            return "Custom release"
        if (previewRelease === normalizedHostRelease(hostRelease))
            return "Host match • Recommended"
        if (releaseIsBootstrapped(previewRelease))
            return "Bootstrapped • Ready"
        return "Selected release"
    }

    function chooseRelease(choice) {
        releaseMenuOpen = false
        if (choice.custom) {
            previewReleaseCustom = true
            previewReleaseCustomized = true
            Qt.callLater(function () { previewReleaseInput.forceActiveFocus() })
            return
        }
        previewRelease = choice.value
        previewReleaseCustom = false
        previewReleaseCustomized = true
        invalidateCreatePlan()
    }

    function chooseJailType(jailType) {
        if (jailType !== "thick" && jailType !== "thin")
            return
        previewJailType = jailType
        invalidateCreatePlan()
    }

    function chooseOutboundPolicy(policy) {
        if (policy !== "internet-only" && policy !== "lan" && policy !== "none")
            return
        previewOutboundPolicy = policy
        invalidateCreatePlan()
    }

    function outboundPolicyFor(jail) {
        if (!jail)
            return "lan"
        for (var i = 0; i < outboundPolicies.length; i += 1) {
            var entry = outboundPolicies[i]
            if (entry.name === jail.name || (entry.ipv4 && entry.ipv4 === jail.ipv4))
                return entry.policy || "lan"
        }
        return "lan"
    }

    function outboundPolicyLabel(policy) {
        if (policy === "internet-only")
            return "Internet only"
        if (policy === "none")
            return "No outbound"
        return "LAN + Internet"
    }

    function portForwardsFor(jail) {
        var matches = []
        if (!jail)
            return matches
        for (var i = 0; i < portForwards.length; i += 1) {
            var entry = portForwards[i]
            if (entry.name === jail.name || (entry.ipv4 && entry.ipv4 === jail.ipv4))
                matches.push(entry)
        }
        return matches
    }

    function validForwardPort(value) {
        var text = String(value || "")
        if (!/^[0-9]+$/.test(text))
            return false
        var port = Number(text)
        return port >= 1 && port <= 65535
    }

    function forwardInputValid() {
        return validForwardPort(forwardHostPort) && validForwardPort(forwardJailPort)
    }

    function requestForwardAdd() {
        if (!forwardInputValid())
            return
        requestAction("forward-add|" + forwardProtocol + "|" + forwardHostPort + "|" + forwardJailPort,
                      "Add port forward",
                      "Expose host " + forwardHostPort + "/" + forwardProtocol.toUpperCase() + " to " + selectedJail.name + ":" + forwardJailPort + " and reload PF?")
    }

    function simpleServiceFor(jail, serviceName) {
        if (!jail)
            return null
        for (var i = 0; i < simpleServices.length; i += 1) {
            var entry = simpleServices[i]
            if (entry.service === serviceName && (entry.name === jail.name || (entry.ipv4 && entry.ipv4 === jail.ipv4)))
                return entry
        }
        return null
    }

    function serviceForwardsFor(jail, service) {
        var matches = []
        if (!jail || !service)
            return matches
        var jailForwards = portForwardsFor(jail)
        for (var i = 0; i < jailForwards.length; i += 1) {
            var entry = jailForwards[i]
            if (String(entry.protocol || "").toLowerCase() === "tcp" && Number(entry.jail_port) === Number(service.port))
                matches.push(entry)
        }
        return matches
    }

    function serviceForwardLabel(forwards, service) {
        if (!forwards || forwards.length === 0 || !service)
            return "Create port forward"
        var hostPorts = []
        for (var i = 0; i < forwards.length; i += 1)
            hostPorts.push(String(forwards[i].host_port))
        return "Host :" + hostPorts.join(", :") + " → nginx :" + service.port
    }

    function serviceVerbLabel(verb) {
        if (verb === "install")
            return "Install + start"
        if (verb === "enable")
            return "Enable at boot"
        if (verb === "disable")
            return "Disable at boot"
        return verb.charAt(0).toUpperCase() + verb.slice(1)
    }

    function requestServiceAction(verb) {
        if (!selectedSimpleService)
            return
        var label = serviceVerbLabel(verb)
        var description = verb === "install"
            ? "Install nginx in " + selectedJail.name + ", enable it at boot, and start it now? This downloads packages inside the jail."
            : label + " nginx in " + selectedJail.name + "?"
        requestAction("service-action|nginx|" + verb, label + " nginx", description)
    }

    function prepareServiceForward() {
        if (!selectedSimpleService)
            return
        forwardProtocol = "tcp"
        forwardJailPort = String(selectedSimpleService.port || 80)
        if (!validForwardPort(forwardHostPort))
            forwardHostPort = "8080"
        statusTone = "info"
        statusMessage = "Prepared TCP forwarding fields for nginx."
    }

    function statusDetailText() {
        if ((statusTone === "error" || lastResultTone === "error") && actionDetails.length > 0)
            return firstNonEmptyLine(actionDetails)
        if (lastResultTimestamp.length > 0)
            return "Updated " + compactTimestamp(lastResultTimestamp)
        return ""
    }

    function valueOrUnknown(value) {
        if (!value || value === "-" || value === "unknown")
            return "Unknown"
        return value
    }

    function canStart(jail) {
        return jail && (jail.state || "").toLowerCase() !== "running"
    }

    function canStop(jail) {
        return jail && (jail.state || "").toLowerCase() === "running"
    }

    function canConsole(jail) {
        return canStop(jail)
    }

    function actionAvailable(actionId) {
        if (!selectedJail || runningAction)
            return false
        if (actionId.indexOf("policy-set|") === 0)
            return selectedJail.backend === "bastille" && selectedJail.ipv4 && selectedJail.ipv4 !== "unknown"
        if (actionId.indexOf("forward-add|") === 0 || actionId.indexOf("forward-remove|") === 0)
            return selectedJail.backend === "bastille" && selectedJail.ipv4 && selectedJail.ipv4 !== "unknown"
        if (actionId.indexOf("service-action|") === 0)
            return selectedJail.backend === "bastille" && (selectedJail.state || "").toLowerCase() === "running" && selectedJail.ipv4 && selectedJail.ipv4 !== "unknown" && selectedSimpleService && selectedSimpleService.status_known
        if (actionId === "start")
            return canStart(selectedJail)
        if (actionId === "stop")
            return canStop(selectedJail)
        if (actionId === "restart")
            return selectedJail.state === "running"
        if (actionId === "console")
            return canConsole(selectedJail)
        return true
    }

    function requestAction(actionId, label, description) {
        if (!actionAvailable(actionId))
            return
        pendingActionId = actionId
        pendingActionLabel = label
        pendingActionDescription = description
    }

    function clearPendingAction() {
        pendingActionId = ""
        pendingActionLabel = ""
        pendingActionDescription = ""
    }

    function confirmPendingAction() {
        if (!pendingActionId || !selectedJail)
            return
        if (pendingActionId.indexOf("policy-set|") === 0) {
            activeActionId = "policy-set"
            activeActionPolicy = pendingActionId.split("|")[1]
            activeActionProtocol = ""
            activeActionHostPort = ""
            activeActionJailPort = ""
            activeActionService = ""
            activeActionServiceVerb = ""
        } else if (pendingActionId.indexOf("forward-add|") === 0 || pendingActionId.indexOf("forward-remove|") === 0) {
            var forwardParts = pendingActionId.split("|")
            activeActionId = forwardParts[0]
            activeActionPolicy = ""
            activeActionProtocol = forwardParts[1]
            activeActionHostPort = forwardParts[2]
            activeActionJailPort = forwardParts[3]
            activeActionService = ""
            activeActionServiceVerb = ""
        } else if (pendingActionId.indexOf("service-action|") === 0) {
            var serviceParts = pendingActionId.split("|")
            activeActionId = serviceParts[0]
            activeActionPolicy = ""
            activeActionProtocol = ""
            activeActionHostPort = ""
            activeActionJailPort = ""
            activeActionService = serviceParts[1]
            activeActionServiceVerb = serviceParts[2]
        } else {
            activeActionId = pendingActionId
            activeActionPolicy = ""
            activeActionProtocol = ""
            activeActionHostPort = ""
            activeActionJailPort = ""
            activeActionService = ""
            activeActionServiceVerb = ""
        }
        activeActionName = selectedJail.name
        activeActionBackend = activeActionId === "policy-set" || activeActionId.indexOf("forward-") === 0 || activeActionId === "service-action" ? selectedJail.ipv4 : selectedJail.backend || "native"
        activeActionLabel = pendingActionLabel
        clearPendingAction()
        runActionProcess()
    }

    function runActionProcess() {
        runningAction = true
        actionDetails = ""
        statusTone = "info"
        statusMessage = activeActionLabel + "..."
        actionStdoutText = ""
        actionStderrText = ""
        actionExitCode = 0
        actionExited = false
        actionStdoutFinished = false
        actionStderrFinished = false
        actionProcess.running = true
    }

    function openCreatePreview() {
        createPreviewVisible = true
        wizardStep = 0
        previewPayload = null
        previewError = ""
        creationStage = "idle"
        creationMessage = ""
        creationError = ""
        creationConfirmation = ""
        creationBootstrapped = false
        storageConfirmation = ""
        storageSetupStage = "idle"
        storageSetupMessage = ""
        storageSetupDetails = ""
        networkConfirmation = ""
        networkSetupStage = "idle"
        networkSetupMessage = ""
        networkSetupDetails = ""
        releaseMenuOpen = false
        chooseDefaultStoragePool()
        if (!previewAddressCustomized && networkInfo && networkInfo.recommended_address)
            previewAddress = networkInfo.recommended_address
    }

    function closeCreatePreview() {
        if (wizardBusy)
            return
        releaseMenuOpen = false
        createPreviewVisible = false
    }

    function invalidateCreatePlan() {
        previewPayload = null
        previewError = ""
        creationConfirmation = ""
        creationStage = "idle"
        creationMessage = ""
        creationError = ""
    }

    function storagePools() {
        return storageInfo && storageInfo.pools ? storageInfo.pools : []
    }

    function storageReady() {
        return bastilleSetup || (storageInfo && storageInfo.configured)
    }

    function chooseDefaultStoragePool() {
        var pools = storagePools()
        if (storageInfo && storageInfo.zfs_pool && storageInfo.zfs_pool.length > 0) {
            selectedStoragePool = storageInfo.zfs_pool
            return
        }
        if (selectedStoragePool.length > 0 && pools.indexOf(selectedStoragePool) >= 0)
            return
        selectedStoragePool = pools.length > 0 ? pools[0] : ""
    }

    function cycleStoragePool() {
        if (storageSetupRunning)
            return
        var pools = storagePools()
        if (pools.length < 2)
            return
        var index = pools.indexOf(selectedStoragePool)
        selectedStoragePool = pools[(index + 1) % pools.length]
        storageConfirmation = ""
        storageSetupStage = "idle"
        storageSetupMessage = ""
        storageSetupDetails = ""
    }

    function storageTargetDataset() {
        if (storageInfo && storageInfo.target_dataset && storageInfo.target_dataset.length > 0)
            return storageInfo.target_dataset
        if (selectedStoragePool.length === 0)
            return "No target available"
        var prefix = storageInfo && storageInfo.zfs_prefix ? storageInfo.zfs_prefix : "bastille"
        return selectedStoragePool + "/" + prefix
    }

    function canConfigureStorage() {
        return !demoMode && tools.bastille && !storageReady() && !storageSetupRunning && selectedStoragePool.length > 0 && storageConfirmation === selectedStoragePool
    }

    function startStorageSetup() {
        if (!canConfigureStorage())
            return
        storageSetupRunning = true
        storageSetupStage = "configuring"
        storageSetupMessage = "Configuring Bastille storage on " + selectedStoragePool + "…"
        storageSetupDetails = ""
        storageStdoutText = ""
        storageStderrText = ""
        storageExitCode = 0
        storageExited = false
        storageStdoutFinished = false
        storageStderrFinished = false
        storageSetupProcess.running = true
    }

    function maybeFinalizeStorageSetup() {
        if (!storageExited || !storageStdoutFinished || !storageStderrFinished)
            return
        storageSetupRunning = false
        var payload = null
        try {
            payload = JSON.parse(storageStdoutText || "{}")
        } catch (error) {
            payload = null
        }
        if (storageExitCode !== 0 || !payload || !payload.ok) {
            storageSetupStage = "failed"
            storageSetupMessage = payload ? payload.message || "Storage setup failed." : "The Jails backend returned invalid storage data."
            storageSetupDetails = payload ? payload.details || storageStderrText : storageStderrText
            return
        }
        storageSetupStage = "complete"
        storageSetupMessage = payload.message || "Configured Bastille storage."
        storageSetupDetails = payload.details || ""
        storageConfirmation = ""
        statusTone = "success"
        statusMessage = storageSetupMessage
        actionDetails = storageSetupDetails
        refreshSnapshot()
    }

    function networkReady() {
        return networkInfo && networkInfo.ready
    }

    function canConfigureNetwork() {
        return !demoMode && tools.bastille && !networkReady() && !networkSetupRunning && previewAddress.length > 0 && networkConfirmation === previewAddress
    }

    function startNetworkSetup() {
        if (!canConfigureNetwork())
            return
        networkSetupRunning = true
        networkSetupStage = "configuring"
        networkSetupMessage = "Configuring Bastille loopback and BSDRunner PF jail rules…"
        networkSetupDetails = ""
        networkStdoutText = ""
        networkStderrText = ""
        networkExitCode = 0
        networkExited = false
        networkStdoutFinished = false
        networkStderrFinished = false
        networkSetupProcess.running = true
    }

    function maybeFinalizeNetworkSetup() {
        if (!networkExited || !networkStdoutFinished || !networkStderrFinished)
            return
        networkSetupRunning = false
        var payload = null
        try {
            payload = JSON.parse(networkStdoutText || "{}")
        } catch (error) {
            payload = null
        }
        if (networkExitCode !== 0 || !payload || !payload.ok) {
            networkSetupStage = "failed"
            networkSetupMessage = payload ? payload.message || "Jail network setup failed." : "The Jails backend returned invalid network data."
            networkSetupDetails = payload ? payload.details || networkStderrText : networkStderrText
            return
        }
        networkSetupStage = "complete"
        networkSetupMessage = payload.message || "Configured Bastille jail networking."
        networkSetupDetails = payload.details || ""
        networkConfirmation = ""
        statusTone = "success"
        statusMessage = networkSetupMessage
        actionDetails = networkSetupDetails
        refreshSnapshot()
    }

    function wizardCanContinue() {
        if (wizardBusy)
            return false
        if (wizardStep === 0)
            return tools.bastille && storageReady()
        if (wizardStep === 1)
            return previewRelease.length > 0
        if (wizardStep === 2)
            return previewAddress.length > 0 && networkReady()
        if (wizardStep === 3)
            return previewName.length > 0 && previewAddress.length > 0
        return false
    }

    function previousWizardStep() {
        if (!wizardBusy && wizardStep > 0) {
            releaseMenuOpen = false
            wizardStep -= 1
            creationConfirmation = ""
            creationStage = "idle"
            creationMessage = ""
            creationError = ""
        }
    }

    function nextWizardStep() {
        if (!wizardCanContinue())
            return
        releaseMenuOpen = false
        if (wizardStep < 3) {
            wizardStep += 1
            return
        }
        wizardStep = 4
        creationConfirmation = ""
        creationStage = "idle"
        creationMessage = ""
        creationError = ""
        runCreatePreview()
    }

    function selectWizardStep(step) {
        if (wizardBusy || step < 0 || step >= wizardStep || creationStage === "complete")
            return
        wizardStep = step
        creationConfirmation = ""
        creationStage = "idle"
        creationMessage = ""
        creationError = ""
    }

    function runCreatePreview() {
        if (createPreviewProcess.running)
            return
        createPreviewLoading = true
        previewPayload = null
        previewError = ""
        previewStdoutText = ""
        previewStderrText = ""
        previewExitCode = 0
        previewExited = false
        previewStdoutFinished = false
        previewStderrFinished = false
        createPreviewProcess.running = true
    }

    function startGuidedCreation() {
        if (wizardBusy || demoMode || !previewPayload || !previewPayload.ready || creationConfirmation !== previewName)
            return
        creationRunning = true
        creationError = ""
        creationMessage = ""
        creationBootstrapped = false
        if (previewPayload.checks && !previewPayload.checks.release_bootstrapped) {
            creationStage = "bootstrapping"
            creationMessage = "Downloading and preparing " + previewRelease + "…"
            startProvisionAction("bootstrap")
        } else {
            creationStage = "creating"
            creationMessage = "Creating " + previewName + "…"
            startProvisionAction("create")
        }
    }

    function startProvisionAction(actionId) {
        provisionAction = actionId
        provisionStdoutText = ""
        provisionStderrText = ""
        provisionExitCode = 0
        provisionExited = false
        provisionStdoutFinished = false
        provisionStderrFinished = false
        provisionProcess.running = true
    }

    function maybeFinalizeProvision() {
        if (!provisionExited || !provisionStdoutFinished || !provisionStderrFinished)
            return
        var payload = null
        try {
            payload = JSON.parse(provisionStdoutText || "{}")
        } catch (error) {
            payload = null
        }
        if (provisionExitCode !== 0 || !payload || !payload.ok) {
            creationRunning = false
            creationStage = "failed"
            creationError = payload ? payload.message || "Jail creation failed." : "The Jails backend returned invalid creation data."
            creationMessage = payload ? payload.details || provisionStderrText : provisionStderrText
            return
        }
        if (provisionAction === "bootstrap") {
            creationBootstrapped = true
            creationStage = "creating"
            creationMessage = "Release ready. Creating " + previewName + "…"
            provisionNextAction = "create"
            provisionContinueTimer.restart()
            return
        }
        creationRunning = false
        creationStage = "complete"
        creationMessage = payload.message || "Created " + previewName + "."
        creationError = ""
        statusTone = "success"
        statusMessage = creationMessage
        actionDetails = payload.details || ""
        selectedJailName = previewName
        selectedJailBackend = "bastille"
        refreshSnapshot()
    }

    function wizardDetailText() {
        if (wizardStep === 0) {
            var storageLines = ["STORAGE", "", "Bastille keeps releases, jail roots, cache, backups, and templates beneath one installation root.", ""]
            if (storageReady()) {
                storageLines.push("[ok] Bastille storage is " + (storageInfo.initialized || bastilleSetup ? "initialized." : "configured."))
                storageLines.push("Pool: " + (storageInfo.zfs_pool || "filesystem-backed"))
                storageLines.push("Dataset: " + (storageInfo.target_dataset || "managed beneath " + (storageInfo.prefix || "/usr/local/bastille")))
                if (!storageInfo.initialized && !bastilleSetup)
                    storageLines.push("The first release bootstrap will create the dataset hierarchy.")
            } else {
                storageLines.push("SELECTED PLAN")
                storageLines.push("Pool: " + (selectedStoragePool || "No ZFS pool detected"))
                storageLines.push("Dataset: " + storageTargetDataset())
                storageLines.push("Mount root: " + (storageInfo.prefix || "/usr/local/bastille"))
                storageLines.push("Command: bastille setup storage " + (selectedStoragePool || "<pool>"))
                storageLines.push("")
                storageLines.push("This command configures storage only. It does not modify PF, interfaces, or jail networking.")
                storageLines.push("The first release bootstrap creates the conventional dataset hierarchy. Existing unrelated datasets are untouched.")
            }
            if (storageSetupStage === "failed") {
                storageLines.push("")
                storageLines.push("[!] " + storageSetupMessage)
                if (storageSetupDetails.length > 0)
                    storageLines.push(storageSetupDetails)
            }
            return storageLines.join("\n")
        }
        if (wizardStep === 1)
            return "USERLAND\n\nChoose a FreeBSD release no newer than the host, then choose how Bastille stores the jail userland. Thick creates an independent copy and is recommended for beginners. Thin shares the bootstrapped release base and uses less space, but base updates require more care.\n\nSelected: " + previewRelease + " • " + previewJailType.charAt(0).toUpperCase() + previewJailType.slice(1) + "\nHost: " + (hostRelease || "Unknown") + "\nBootstrapped: " + (bastilleReleases.length > 0 ? bastilleReleases.join(", ") : "None; the selected release will be downloaded.")
        if (wizardStep === 2) {
            var networkLines = ["NETWORK", "", "The jail uses a private IPv4 address on Bastille's loopback interface. BSDRunner adds only the PF NAT and anchor rules needed for outbound access and future port redirects.", ""]
            networkLines.push((networkInfo.loopback_ready ? "[ok] " : "[!] ") + "Loopback " + (networkInfo.loopback_interface || "bastille0"))
            networkLines.push((networkInfo.pf_running ? "[ok] " : "[!] ") + "PF running")
            networkLines.push((networkInfo.nat_ready ? "[ok] " : "[!] ") + "Bastille NAT table")
            networkLines.push((networkInfo.rdr_anchor_ready ? "[ok] " : "[!] ") + "Port-redirect anchor")
            networkLines.push((networkInfo.filter_anchor_ready ? "[ok] " : "[!] ") + "Bastille filter anchor")
            networkLines.push("")
            networkLines.push("Jail address: " + previewAddress)
            networkLines.push("External interface: " + (networkInfo.external_interface || "Not detected"))
            networkLines.push("")
            networkLines.push("After your typed confirmation, setup runs only `bastille setup --yes loopback`, then renders, validates, installs, and reloads BSDRunner's managed PF profile. It never runs `bastille setup pf`.")
            if (networkSetupStage === "failed") {
                networkLines.push("")
                networkLines.push("[!] " + networkSetupMessage)
                if (networkSetupDetails.length > 0)
                    networkLines.push(networkSetupDetails)
            }
            return networkLines.join("\n")
        }
        if (wizardStep === 3)
            return "CONFIG\n\nGive the jail a unique name and choose whether it starts at boot. The selected address is " + previewAddress + ". The backend rechecks the name, address, active routes, and network readiness immediately before creation."

        var progress = ""
        if (creationStage === "bootstrapping")
            progress = "PROGRESS\n[>] Bootstrapping " + previewRelease + "\n[ ] Creating " + previewName + "\n\n"
        else if (creationStage === "creating")
            progress = "PROGRESS\n" + (creationBootstrapped ? "[ok] Release bootstrapped\n" : "[ok] Release already available\n") + "[>] Creating " + previewName + "\n\n"
        else if (creationStage === "complete")
            progress = "COMPLETE\n[ok] " + creationMessage + "\n\n"
        else if (creationStage === "failed")
            progress = "NEEDS ATTENTION\n[!] " + creationError + "\n" + creationMessage + "\n\n"
        return progress + createPreviewText()
    }

    function maybeFinalizeCreatePreview() {
        if (!previewExited || !previewStdoutFinished || !previewStderrFinished)
            return
        createPreviewLoading = false
        var payload = null
        try {
            payload = JSON.parse(previewStdoutText || "{}")
        } catch (error) {
            previewError = "The Jails backend returned invalid preview data."
            return
        }
        if (previewExitCode !== 0 || !payload.ok) {
            previewError = payload.message || previewStderrText || "Unable to build the create preview."
            return
        }
        previewPayload = payload
    }

    function createPreviewText() {
        if (previewError.length > 0)
            return previewError
        if (!previewPayload)
            return "Enter the proposed jail details, then generate a read-only plan. No commands will run."

        var checks = previewPayload.checks || {}
        var lines = ["READINESS"]
        lines.push((checks.bastille_installed ? "[ok] " : "[!] ") + "Bastille installed")
        lines.push((checks.storage_configured ? "[ok] " : "[!] ") + "Bastille storage configured")
        lines.push((checks.network_ready ? "[ok] " : "[!] ") + "Bastille loopback and PF jail rules ready")
        lines.push((checks.dns_ready ? "[ok] " : "[!] ") + "Reachable DNS resolver available")
        lines.push((checks.bastille_setup ? "[ok] " : "[plan] ") + "Bastille inventory " + (checks.bastille_setup ? "readable" : "will initialize during bootstrap"))
        lines.push((checks.name_available ? "[ok] " : "[!] ") + "Jail name available")
        lines.push((checks.address_available ? "[ok] " : "[!] ") + "IP address available")
        lines.push((checks.address_route_safe ? "[ok] " : "[!] ") + "IP address does not overlap an active host route")
        lines.push("[plan] Outbound policy: " + outboundPolicyLabel(previewPayload.inputs ? previewPayload.inputs.outbound_policy : previewOutboundPolicy))
        lines.push((checks.host_compatible ? "[ok] " : "[!] ") + "Host release compatible" + (checks.host_release ? " (" + checks.host_release + ")" : ""))
        lines.push((checks.release_bootstrapped ? "[ok] " : "[plan] ") + "Release " + (checks.release_bootstrapped ? "already bootstrapped" : "will be bootstrapped"))
        lines.push("")
        lines.push("COMMANDS")
        var commands = previewPayload.commands || []
        for (var i = 0; i < commands.length; i += 1)
            lines.push("$ " + commands[i])
        lines.push("")
        lines.push("NOTES")
        var notes = previewPayload.notes || []
        for (var j = 0; j < notes.length; j += 1)
            lines.push("• " + notes[j])
        return lines.join("\n")
    }

    function refreshSnapshot() {
        if (snapshotProcess.running)
            return
        loading = true
        snapshotStdoutText = ""
        snapshotStderrText = ""
        snapshotExitCode = 0
        snapshotExited = false
        snapshotStdoutFinished = false
        snapshotStderrFinished = false
        snapshotProcess.running = true
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return
        applySnapshot(snapshotStdoutText, snapshotExitCode, snapshotStderrText)
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return
        applyActionResult(actionStdoutText, actionExitCode, actionStderrText)
    }

    function applySnapshot(text, exitCode, stderrText) {
        loading = false
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            statusTone = "error"
            statusMessage = "The Jails backend returned invalid JSON."
            actionDetails = stderrText || text || ""
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load jail status."
            return
        }

        tools = payload.tools || {}
        services = payload.services || {}
        demoMode = payload.demo || false
        bastilleReleases = payload.bastille_releases || []
        bastilleSetup = payload.bastille_setup || false
        storageInfo = payload.storage || {"configured": bastilleSetup, "initialized": bastilleSetup, "prefix": "/usr/local/bastille", "zfs_pool": "", "zfs_prefix": "bastille", "target_dataset": "", "pools": []}
        chooseDefaultStoragePool()
        networkInfo = payload.network || {"ready": false, "loopback_ready": false, "pf_running": false, "nat_ready": false, "rdr_anchor_ready": false, "filter_anchor_ready": false, "loopback_interface": "bastille0", "external_interface": "", "recommended_address": "10.0.0.20/24"}
        if (!previewAddressCustomized && networkInfo.recommended_address)
            previewAddress = networkInfo.recommended_address
        hostRelease = payload.host_release || ""
        if (!previewReleaseCustomized) {
            previewRelease = defaultPreviewRelease()
            previewReleaseCustom = false
        }
        runningJails = payload.running || []
        configuredJails = payload.configured || []
        bastilleJails = payload.bastille || []
        outboundPolicies = payload.outbound_policies || []
        portForwards = payload.port_forwards || []
        simpleServices = payload.simple_services || []
        lastResultTone = payload.last_result ? payload.last_result.tone || "info" : "info"
        lastResultMessage = payload.last_result ? payload.last_result.message || payload.message : payload.message
        lastResultTimestamp = payload.last_result ? payload.last_result.timestamp || "" : ""
        statusTone = lastResultTone
        statusMessage = payload.message || "Loaded jail status."

        if (jails.length > 0 && !findJail(selectedJailName, selectedJailBackend))
            selectJail(jails[0])
        else if (jails.length === 0)
            selectJail(null)
    }

    function applyActionResult(text, exitCode, stderrText) {
        runningAction = false
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            payload = null
        }

        if (payload && payload.ok && exitCode === 0) {
            statusTone = activeActionId === "stop" ? "warning" : "success"
            statusMessage = payload.message || "Jail action completed."
            actionDetails = payload.details || ""
        } else if (payload) {
            statusTone = "error"
            statusMessage = payload.message || "Jail action failed."
            actionDetails = payload.details || stderrText || ""
        } else {
            statusTone = "error"
            statusMessage = "The Jails backend returned invalid JSON."
            actionDetails = stderrText || text || ""
        }

        activeActionId = ""
        activeActionName = ""
        activeActionBackend = ""
        activeActionPolicy = ""
        activeActionProtocol = ""
        activeActionHostPort = ""
        activeActionJailPort = ""
        activeActionService = ""
        activeActionServiceVerb = ""
        activeActionLabel = ""
        refreshSnapshot()
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "snapshot"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotStdoutText = text
                snapshotProcess.controller.snapshotStdoutFinished = true
                snapshotProcess.controller.maybeFinalizeSnapshot()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotStderrText = text
                snapshotProcess.controller.snapshotStderrFinished = true
                snapshotProcess.controller.maybeFinalizeSnapshot()
            }
        }
        onExited: function (exitCode) {
            snapshotProcess.controller.snapshotExitCode = exitCode
            snapshotProcess.controller.snapshotExited = true
            snapshotProcess.controller.maybeFinalizeSnapshot()
        }
    }

    Process {
        id: actionProcess
        property var controller: root

        command: root.activeActionId === "policy-set"
            ? ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "policy-set", root.activeActionName, root.activeActionBackend, root.activeActionPolicy, root.activeActionName]
            : root.activeActionId === "forward-add" || root.activeActionId === "forward-remove"
                ? ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", root.activeActionId, root.activeActionName, root.activeActionBackend, root.activeActionProtocol, root.activeActionHostPort, root.activeActionJailPort, root.activeActionName]
                : root.activeActionId === "service-action"
                    ? ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "service-action", root.activeActionName, root.activeActionBackend, root.activeActionService, root.activeActionServiceVerb, root.activeActionName]
                : ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", root.activeActionId, root.activeActionName, root.activeActionBackend]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                actionProcess.controller.actionStdoutText = text
                actionProcess.controller.actionStdoutFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                actionProcess.controller.actionStderrText = text
                actionProcess.controller.actionStderrFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }
        onExited: function (exitCode) {
            actionProcess.controller.actionExitCode = exitCode
            actionProcess.controller.actionExited = true
            actionProcess.controller.maybeFinalizeAction()
        }
    }

    Process {
        id: createPreviewProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "preview", root.previewName, root.previewRelease, root.previewAddress, root.previewAutostart ? "yes" : "no", root.previewJailType, root.previewOutboundPolicy]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                createPreviewProcess.controller.previewStdoutText = text
                createPreviewProcess.controller.previewStdoutFinished = true
                createPreviewProcess.controller.maybeFinalizeCreatePreview()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                createPreviewProcess.controller.previewStderrText = text
                createPreviewProcess.controller.previewStderrFinished = true
                createPreviewProcess.controller.maybeFinalizeCreatePreview()
            }
        }
        onExited: function (exitCode) {
            createPreviewProcess.controller.previewExitCode = exitCode
            createPreviewProcess.controller.previewExited = true
            createPreviewProcess.controller.maybeFinalizeCreatePreview()
        }
    }

    Process {
        id: storageSetupProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "storage-setup", root.selectedStoragePool, root.storageConfirmation]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                storageSetupProcess.controller.storageStdoutText = text
                storageSetupProcess.controller.storageStdoutFinished = true
                storageSetupProcess.controller.maybeFinalizeStorageSetup()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                storageSetupProcess.controller.storageStderrText = text
                storageSetupProcess.controller.storageStderrFinished = true
                storageSetupProcess.controller.maybeFinalizeStorageSetup()
            }
        }
        onExited: function (exitCode) {
            storageSetupProcess.controller.storageExitCode = exitCode
            storageSetupProcess.controller.storageExited = true
            storageSetupProcess.controller.maybeFinalizeStorageSetup()
        }
    }

    Process {
        id: networkSetupProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "network-setup", root.previewAddress, root.networkConfirmation]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                networkSetupProcess.controller.networkStdoutText = text
                networkSetupProcess.controller.networkStdoutFinished = true
                networkSetupProcess.controller.maybeFinalizeNetworkSetup()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                networkSetupProcess.controller.networkStderrText = text
                networkSetupProcess.controller.networkStderrFinished = true
                networkSetupProcess.controller.maybeFinalizeNetworkSetup()
            }
        }
        onExited: function (exitCode) {
            networkSetupProcess.controller.networkExitCode = exitCode
            networkSetupProcess.controller.networkExited = true
            networkSetupProcess.controller.maybeFinalizeNetworkSetup()
        }
    }

    Process {
        id: provisionProcess
        property var controller: root

        command: root.provisionAction === "bootstrap"
            ? ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "bootstrap", root.previewRelease, root.previewRelease]
            : ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "create", root.previewName, root.previewRelease, root.previewAddress, root.previewAutostart ? "yes" : "no", root.creationConfirmation, root.previewJailType, root.previewOutboundPolicy]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                provisionProcess.controller.provisionStdoutText = text
                provisionProcess.controller.provisionStdoutFinished = true
                provisionProcess.controller.maybeFinalizeProvision()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                provisionProcess.controller.provisionStderrText = text
                provisionProcess.controller.provisionStderrFinished = true
                provisionProcess.controller.maybeFinalizeProvision()
            }
        }
        onExited: function (exitCode) {
            provisionProcess.controller.provisionExitCode = exitCode
            provisionProcess.controller.provisionExited = true
            provisionProcess.controller.maybeFinalizeProvision()
        }
    }

    Timer {
        id: provisionContinueTimer
        interval: 100
        onTriggered: {
            if (root.provisionNextAction.length === 0)
                return
            if (provisionProcess.running) {
                restart()
                return
            }
            var nextAction = root.provisionNextAction
            root.provisionNextAction = ""
            root.startProvisionAction(nextAction)
        }
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    FloatingWindow {
        visible: true
        title: "BSDRunner Jails"
        minimumSize: Qt.size(1080, 660)
        maximumSize: Qt.size(1080, 660)
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
                    height: 104
                    z: 10
                    spacing: 14

                    Rectangle {
                        width: 320
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.headlineTone())

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 54
                                height: 54
                                radius: 27
                                y: 7
                                color: Qt.alpha(root.toneColor(root.headlineTone()), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.headlineTone())

                                Text {
                                    anchors.centerIn: parent
                                    text: "JLS"
                                    color: root.toneColor(root.headlineTone())
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 74
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.headline()
                                    color: root.palette.primaryText
                                    font.pixelSize: 27
                                    minimumPixelSize: 18
                                    fontSizeMode: Text.HorizontalFit
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.jails.length + " known, " + root.runningCount() + " running"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.tools.bastille ? "Bastille detected" : "Native jail mode"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 334
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.statusTone)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Rectangle {
                                width: 8
                                height: parent.height
                                radius: 4
                                color: root.toneColor(root.statusTone)
                            }

                            Column {
                                width: parent.width - 280
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: root.statusMessage
                                    color: root.palette.primaryText
                                    font.pixelSize: 18
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.statusDetailText().length > 0 ? root.statusDetailText() : "Jails share the FreeBSD kernel. Each jail gets its own userland, network identity, and filesystem root."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: headerCreatePreviewButton
                                property bool tooltipVisible: false

                                width: 140
                                height: 38
                                z: tooltipVisible ? 30 : 0
                                radius: 7
                                color: headerCreatePreviewMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.accent, 0.18)
                                border.width: 1
                                border.color: root.palette.accent
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Create Basic Jail"
                                    color: root.palette.primaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: headerCreatePreviewMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: previewTooltipTimer.restart()
                                    onExited: {
                                        previewTooltipTimer.stop()
                                        headerCreatePreviewButton.tooltipVisible = false
                                    }
                                    onClicked: root.openCreatePreview()
                                }

                                Timer {
                                    id: previewTooltipTimer
                                    interval: 350
                                    onTriggered: headerCreatePreviewButton.tooltipVisible = true
                                }

                                Rectangle {
                                    visible: headerCreatePreviewButton.tooltipVisible
                                    width: 276
                                    height: 48
                                    x: (parent.width - width) / 2
                                    y: parent.height + 7
                                    radius: 6
                                    color: root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.palette.accent

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: "Walk through storage, userland, networking, config, and creation with Bastille."
                                        color: root.palette.primaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            Rectangle {
                                width: 92
                                height: 38
                                radius: 7
                                color: refreshMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.loading ? "Loading" : "Refresh"
                                    color: root.palette.primaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.loading && !root.runningAction
                                    onClicked: root.refreshSnapshot()
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 118
                    spacing: 14

                    Rectangle {
                        width: 316
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Row {
                                width: parent.width
                                height: 26
                                spacing: 8

                                Text {
                                    width: parent.width - 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Jail Inventory"
                                    color: root.palette.accent
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Rectangle {
                                    width: 112
                                    height: 26
                                    radius: 6
                                    color: mapToggleMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.beginnerMapVisible ? root.palette.accent : root.palette.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.beginnerMapVisible ? "Hide Map" : "Show Map"
                                        color: root.beginnerMapVisible ? root.palette.accent : root.palette.primaryText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: mapToggleMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.beginnerMapVisible = !root.beginnerMapVisible
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: 7
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    text: root.jails.length === 0 ? "No configured jails found" : "Select a jail to inspect it"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Flickable {
                                width: parent.width
                                height: parent.height - 90
                                contentHeight: jailListColumn.height
                                clip: true

                                Column {
                                    id: jailListColumn
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: root.jails

                                        Rectangle {
                                            id: jailRow
                                            required property var modelData

                                            width: jailListColumn.width
                                            height: 78
                                            radius: 8
                                            color: root.selectedJailName === jailRow.modelData.name && root.selectedJailBackend === jailRow.modelData.backend ? root.palette.cardHover : root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.selectedJailName === jailRow.modelData.name && root.selectedJailBackend === jailRow.modelData.backend ? root.toneColor(root.stateTone(jailRow.modelData)) : root.palette.frameBorder

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Rectangle {
                                                    width: 12
                                                    height: 12
                                                    radius: 6
                                                    color: root.toneColor(root.stateTone(jailRow.modelData))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Column {
                                                    width: parent.width - 22
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 3

                                                    Text {
                                                        width: parent.width
                                                        text: jailRow.modelData.name || "Unnamed jail"
                                                        color: root.palette.primaryText
                                                        font.pixelSize: 15
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: root.backendLabel(jailRow.modelData) + " / " + root.valueOrUnknown(jailRow.modelData.state)
                                                        color: root.palette.secondaryText
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: root.valueOrUnknown(jailRow.modelData.ipv4)
                                                        color: root.palette.mutedText
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.selectJail(jailRow.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: root.beginnerMapVisible ? 382 : parent.width - 330
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 14
                            contentWidth: width
                            contentHeight: centerContent.height
                            clip: true

                            Column {
                                id: centerContent

                                width: parent.width
                                spacing: 12

                            Text {
                                width: parent.width
                                text: root.selectedJail ? root.selectedJail.name : "Select a jail"
                                color: root.palette.primaryText
                                font.pixelSize: 24
                                minimumPixelSize: 16
                                fontSizeMode: Text.HorizontalFit
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.selectedJail ? root.backendLabel(root.selectedJail) + " / " + root.valueOrUnknown(root.selectedJail.state) : "A jail is a lightweight FreeBSD system boundary."
                                color: root.selectedJail ? root.toneColor(root.stateTone(root.selectedJail)) : root.palette.secondaryText
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: [
                                        {"label": "JID", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.jid) : "None"},
                                        {"label": "IP address", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.ipv4) : "None"},
                                        {"label": "Hostname", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.hostname) : "None"},
                                        {"label": "Autostart", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.autostart) : "None"},
                                        {"label": "Release", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.release) : "None"},
                                        {"label": "Root path", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.path) : "None"}
                                    ]

                                    Rectangle {
                                        id: detailCell
                                        required property var modelData

                                        width: (parent.width - 8) / 2
                                        height: 58
                                        radius: 7
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: detailCell.modelData.label
                                                color: root.palette.mutedText
                                                font.pixelSize: 10
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: detailCell.modelData.value
                                                color: root.palette.primaryText
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Outbound policy"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.selectedJail ? "Current: " + root.outboundPolicyLabel(root.outboundPolicyFor(root.selectedJail)) : "Select a Bastille jail to manage egress."
                                color: root.palette.secondaryText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                width: parent.width
                                height: 82
                                spacing: 6

                                Repeater {
                                    model: root.outboundPolicyChoices

                                    Rectangle {
                                        id: outboundPolicyCard
                                        required property var modelData
                                        readonly property bool selected: root.selectedJail && root.outboundPolicyFor(root.selectedJail) === modelData.id
                                        readonly property string actionId: "policy-set|" + modelData.id

                                        width: (parent.width - 12) / 3
                                        height: parent.height
                                        radius: 7
                                        color: outboundPolicyMouse.containsMouse && root.actionAvailable(actionId) ? root.palette.cardHover : selected ? Qt.alpha(root.palette.accent, 0.16) : root.palette.panelBackground
                                        opacity: root.actionAvailable(actionId) ? 1.0 : 0.45
                                        border.width: 1
                                        border.color: selected ? root.palette.accent : root.palette.panelBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 7
                                            spacing: 4

                                            Text {
                                                width: parent.width
                                                text: (outboundPolicyCard.selected ? "✓ " : "") + outboundPolicyCard.modelData.label
                                                color: outboundPolicyCard.selected ? root.palette.accent : root.palette.primaryText
                                                font.pixelSize: 13
                                                font.bold: true
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: outboundPolicyCard.modelData.detail
                                                color: root.palette.mutedText
                                                font.pixelSize: 12
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: outboundPolicyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: root.actionAvailable(outboundPolicyCard.actionId) && !outboundPolicyCard.selected
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.requestAction(outboundPolicyCard.actionId, "Change outbound policy", "Apply " + outboundPolicyCard.modelData.label + " to " + root.selectedJail.name + " and reload PF?")
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Port forwarding"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.selectedJail && root.selectedJail.backend === "bastille"
                                    ? "Expose a port on " + (root.networkInfo.external_interface || "the host uplink") + " to this jail. Only add services you intend other machines to reach."
                                    : "Select a Bastille jail to manage inbound ports."
                                color: root.palette.secondaryText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                width: parent.width
                                height: 58
                                spacing: 6
                                opacity: root.actionAvailable("forward-add|draft") ? 1.0 : 0.45

                                Column {
                                    width: 72
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Protocol"
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 38
                                        radius: 6
                                        color: forwardProtocolMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.forwardProtocol.toUpperCase()
                                            color: root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: forwardProtocolMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: root.actionAvailable("forward-add|draft")
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.forwardProtocol = root.forwardProtocol === "tcp" ? "udp" : "tcp"
                                        }
                                    }
                                }

                                Column {
                                    width: (parent.width - 96) / 2
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Host port"
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 38
                                        radius: 6
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: forwardHostPortInput.activeFocus ? root.palette.accent : root.validForwardPort(root.forwardHostPort) ? root.palette.panelBorder : root.palette.danger

                                        TextInput {
                                            id: forwardHostPortInput

                                            anchors.fill: parent
                                            anchors.margins: 9
                                            text: root.forwardHostPort
                                            enabled: root.actionAvailable("forward-add|draft")
                                            color: root.palette.primaryText
                                            selectionColor: root.palette.accent
                                            selectedTextColor: root.palette.panelBackground
                                            font.pixelSize: 13
                                            maximumLength: 5
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            onTextEdited: root.forwardHostPort = text
                                        }
                                    }
                                }

                                Text {
                                    width: 6
                                    height: parent.height
                                    text: "→"
                                    color: root.palette.mutedText
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignBottom
                                    bottomPadding: 10
                                }

                                Column {
                                    width: (parent.width - 96) / 2
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Jail port"
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 38
                                        radius: 6
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: forwardJailPortInput.activeFocus ? root.palette.accent : root.validForwardPort(root.forwardJailPort) ? root.palette.panelBorder : root.palette.danger

                                        TextInput {
                                            id: forwardJailPortInput

                                            anchors.fill: parent
                                            anchors.margins: 9
                                            text: root.forwardJailPort
                                            enabled: root.actionAvailable("forward-add|draft")
                                            color: root.palette.primaryText
                                            selectionColor: root.palette.accent
                                            selectedTextColor: root.palette.panelBackground
                                            font.pixelSize: 13
                                            maximumLength: 5
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            onTextEdited: root.forwardJailPort = text
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 36
                                radius: 6
                                color: forwardAddMouse.enabled ? (forwardAddMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.18)) : root.palette.panelBackground
                                border.width: 1
                                border.color: forwardAddMouse.enabled ? root.palette.success : root.palette.panelBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "Add port forward"
                                    color: forwardAddMouse.enabled ? root.palette.primaryText : root.palette.mutedText
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: forwardAddMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.actionAvailable("forward-add|draft") && root.forwardInputValid()
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.requestForwardAdd()
                                }
                            }

                            Text {
                                visible: root.portForwardsFor(root.selectedJail).length === 0
                                width: parent.width
                                text: "No port forwards for this jail."
                                color: root.palette.mutedText
                                font.pixelSize: 12
                            }

                            Repeater {
                                model: root.portForwardsFor(root.selectedJail)

                                Rectangle {
                                    id: forwardRow
                                    required property var modelData
                                    readonly property string removeActionId: "forward-remove|" + modelData.protocol + "|" + modelData.host_port + "|" + modelData.jail_port

                                    width: parent.width
                                    height: 46
                                    radius: 7
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.frameBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            width: parent.width - 74
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: forwardRow.modelData.host_port + "/" + forwardRow.modelData.protocol.toUpperCase() + "  →  " + forwardRow.modelData.ipv4 + ":" + forwardRow.modelData.jail_port
                                            color: root.palette.primaryText
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: 66
                                            height: 28
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 6
                                            color: forwardRemoveMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.danger, 0.12)
                                            border.width: 1
                                            border.color: root.palette.danger

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Remove"
                                                color: root.palette.primaryText
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: forwardRemoveMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.actionAvailable(forwardRow.removeActionId)
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.requestAction(forwardRow.removeActionId,
                                                                              "Remove port forward",
                                                                              "Stop forwarding host " + forwardRow.modelData.host_port + "/" + forwardRow.modelData.protocol.toUpperCase() + " to " + root.selectedJail.name + ":" + forwardRow.modelData.jail_port + " and reload PF?")
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Simple services"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Rectangle {
                                id: simpleServiceCard

                                width: parent.width
                                height: !root.selectedSimpleService ? 92 : !root.selectedSimpleService.status_known ? 122 : root.selectedSimpleService.installed ? 202 : 154
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.selectedSimpleService && root.selectedSimpleService.running ? root.palette.success : root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 7

                                    Row {
                                        width: parent.width
                                        height: 22
                                        spacing: 8

                                        Text {
                                            width: parent.width - 90
                                            text: root.selectedSimpleService ? "nginx" : "nginx web server"
                                            color: root.palette.primaryText
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: 82
                                            horizontalAlignment: Text.AlignRight
                                            text: root.selectedSimpleService && root.selectedSimpleService.status_known
                                                ? (root.selectedJail.state || "").toLowerCase() !== "running" ? "Jail stopped" : root.selectedSimpleService.running ? "Running" : root.selectedSimpleService.installed ? "Stopped" : "Available"
                                                : ""
                                            color: root.selectedSimpleService && root.selectedSimpleService.running ? root.palette.success : root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: !root.selectedJail || root.selectedJail.backend !== "bastille"
                                            ? "Guided services are available for Bastille jails."
                                            : (root.selectedJail.state || "").toLowerCase() !== "running"
                                                ? "Start this jail to inspect and manage nginx."
                                                : !root.selectedSimpleService || !root.selectedSimpleService.status_known
                                                    ? "Service status is temporarily unavailable. Refresh to try again."
                                                : root.selectedSimpleService.installed
                                                    ? "Static web server and reverse proxy • TCP 80"
                                                    : "Install nginx, enable it at boot, and start it with one confirmed action."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        visible: root.selectedSimpleService && root.selectedSimpleService.status_known
                                        width: parent.width
                                        text: root.selectedSimpleService
                                            ? (root.selectedSimpleService.installed ? "Installed" : "Not installed") + "  •  " + (root.selectedSimpleService.enabled ? "Boot enabled" : "Boot disabled")
                                            : ""
                                        color: root.selectedSimpleService && root.selectedSimpleService.installed ? root.palette.primaryText : root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Row {
                                        visible: root.selectedSimpleService && root.selectedSimpleService.status_known
                                        width: parent.width
                                        height: visible ? 34 : 0
                                        spacing: 6

                                        Rectangle {
                                            readonly property string verb: root.selectedSimpleService && !root.selectedSimpleService.installed ? "install" : root.selectedSimpleService && root.selectedSimpleService.running ? "restart" : "start"

                                            width: root.selectedSimpleService && root.selectedSimpleService.running ? (parent.width - 6) / 2 : parent.width
                                            height: parent.height
                                            radius: 6
                                            color: servicePrimaryMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.accent, 0.14)
                                            border.width: 1
                                            border.color: root.palette.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.selectedSimpleService && !root.selectedSimpleService.installed ? "Install + start" : root.selectedSimpleService && root.selectedSimpleService.running ? "Restart" : "Start"
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: servicePrimaryMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.actionAvailable("service-action|nginx|" + parent.verb)
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.requestServiceAction(parent.verb)
                                            }
                                        }

                                        Rectangle {
                                            visible: root.selectedSimpleService && root.selectedSimpleService.running
                                            width: visible ? (parent.width - 6) / 2 : 0
                                            height: parent.height
                                            radius: 6
                                            color: serviceStopMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.warning, 0.14)
                                            border.width: 1
                                            border.color: root.palette.warning

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Stop " + (root.selectedSimpleService ? (root.selectedSimpleService.label || root.selectedSimpleService.service || "service") : "service")
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: serviceStopMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.actionAvailable("service-action|nginx|stop")
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.requestServiceAction("stop")
                                            }
                                        }
                                    }

                                    Row {
                                        visible: root.selectedSimpleService && root.selectedSimpleService.status_known && root.selectedSimpleService.installed
                                        width: parent.width
                                        height: visible ? 32 : 0
                                        spacing: 6

                                        Rectangle {
                                            width: (parent.width - 6) / 2
                                            height: parent.height
                                            radius: 6
                                            color: serviceBootMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.panelBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.selectedSimpleService && root.selectedSimpleService.enabled ? "Disable at boot" : "Enable at boot"
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: serviceBootMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.actionAvailable("service-action|nginx|boot")
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.requestServiceAction(root.selectedSimpleService.enabled ? "disable" : "enable")
                                            }
                                        }

                                        Rectangle {
                                            readonly property bool published: root.selectedServiceForwards.length > 0

                                            width: (parent.width - 6) / 2
                                            height: parent.height
                                            radius: 6
                                            color: published ? Qt.alpha(root.palette.success, 0.14) : serviceForwardMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: published ? root.palette.success : root.palette.panelBorder

                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                text: root.serviceForwardLabel(root.selectedServiceForwards, root.selectedSimpleService)
                                                color: parent.published ? root.palette.success : root.palette.secondaryText
                                                font.pixelSize: parent.published ? 10 : 11
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: serviceForwardMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !parent.published && root.actionAvailable("forward-add|draft")
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.prepareServiceForward()
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: root.pendingActionId ? 108 : 0
                                visible: root.pendingActionId.length > 0
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.toneColor("warning")

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: root.pendingActionLabel
                                        color: root.palette.primaryText
                                        font.pixelSize: 14
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.pendingActionDescription
                                        color: root.palette.secondaryText
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        width: parent.width
                                        height: 28
                                        spacing: 8

                                        Rectangle {
                                            width: 92
                                            height: parent.height
                                            radius: 6
                                            color: confirmMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.warning, 0.18)
                                            border.width: 1
                                            border.color: root.palette.warning

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Confirm"
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: confirmMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.confirmPendingAction()
                                            }
                                        }

                                        Rectangle {
                                            width: 80
                                            height: parent.height
                                            radius: 6
                                            color: cancelMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.panelBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Cancel"
                                                color: root.palette.secondaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: cancelMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.clearPendingAction()
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Actions"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: [
                                        {"id": "start", "label": "Start", "detail": "Boot this jail userland"},
                                        {"id": "stop", "label": "Stop", "detail": "Shut the jail down"},
                                        {"id": "restart", "label": "Restart", "detail": "Stop, then start again"},
                                        {"id": "console", "label": "Console", "detail": "Open a root shell"}
                                    ]

                                    Rectangle {
                                        id: actionCell
                                        required property var modelData

                                        width: (parent.width - 8) / 2
                                        height: 58
                                        radius: 7
                                        color: actionMouse.containsMouse && root.actionAvailable(actionCell.modelData.id) ? root.palette.cardHover : root.palette.panelBackground
                                        opacity: root.actionAvailable(actionCell.modelData.id) ? 1.0 : 0.45
                                        border.width: 1
                                        border.color: root.palette.panelBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: actionCell.modelData.label
                                                color: root.palette.primaryText
                                                font.pixelSize: 13
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: actionCell.modelData.detail
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: root.actionAvailable(actionCell.modelData.id)
                                            onClicked: root.requestAction(actionCell.modelData.id, actionCell.modelData.label, actionCell.modelData.label + " " + root.selectedJail.name + "?")
                                        }
                                    }
                                }
                            }

                            }
                        }
                    }

                    Rectangle {
                        visible: root.beginnerMapVisible
                        width: root.beginnerMapVisible ? parent.width - 726 : 0
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 14
                            contentWidth: width
                            contentHeight: beginnerContent.height
                            clip: true

                            Column {
                                id: beginnerContent

                                width: parent.width
                                spacing: 12

                            Text {
                                width: parent.width
                                text: "Beginner Map"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: Math.max(76, beginnerTipText.implicitHeight + 20)
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    id: beginnerTipText

                                    anchors.fill: parent
                                    anchors.margins: 10
                                    text: root.selectedJail ? "Tip: start with a service jail for things like Postgres, Redis, nginx, or a development daemon. Desktop app jails need extra display, audio, and file permissions." : "Pick a jail from the inventory to see safe lifecycle actions."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Repeater {
                                model: root.beginnerTopics

                                Rectangle {
                                    id: mapCard
                                    required property var modelData
                                    readonly property bool selected: root.selectedBeginnerTopic === modelData.id

                                    width: parent.width
                                    height: 78
                                    radius: 8
                                    color: mapMouse.containsMouse ? root.palette.cardHover : (selected ? Qt.alpha(root.palette.accent, 0.14) : root.palette.panelBackground)
                                    border.width: 1
                                    border.color: selected ? root.palette.accent : root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: mapCard.modelData.title
                                            color: root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: mapCard.modelData.body
                                            color: root.palette.secondaryText
                                            font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: mapMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedBeginnerTopic = mapCard.modelData.id
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 124
                                radius: 8
                                color: Qt.alpha(root.palette.accent, 0.10)
                                border.width: 1
                                border.color: root.palette.accent

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Selected step details"
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.selectedBeginner ? root.selectedBeginner.detail : ""
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 5
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 112
                                radius: 8
                                color: root.tools.bastille ? Qt.alpha(root.palette.success, 0.12) : root.palette.panelBackground
                                border.width: 1
                                border.color: root.tools.bastille ? root.palette.success : root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Bastille"
                                        color: root.tools.bastille ? root.palette.success : root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.tools.bastille ? "Installed. This UI can list Bastille jails and use Bastille lifecycle commands." : "Not installed. Native jail status still works; Bastille can remain an optional automation layer."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 86
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Create Jail"
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Start a guided flow through Storage, Userland, Network, Config, and Lifecycle. Nothing changes until typed confirmation."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openCreatePreview()
                                }
                            }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.createPreviewVisible
                anchors.fill: parent
                z: 20
                color: Qt.alpha(root.palette.panelBackground, 0.92)

                MouseArea {
                    anchors.fill: parent
                }

                Rectangle {
                    width: 960
                    height: 610
                    anchors.centerIn: parent
                    radius: 10
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.accent

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Row {
                            width: parent.width
                            height: 42
                            spacing: 12

                            Column {
                                width: parent.width - 54
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: "Create Basic Jail"
                                    color: root.palette.primaryText
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: "Guided " + root.previewJailType + " jail • every setup or creation change requires typed confirmation"
                                    color: root.palette.accent
                                    font.pixelSize: root.wizardControlFontSize
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                width: 42
                                height: 34
                                radius: 7
                                color: closePreviewMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: root.palette.primaryText
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                MouseArea {
                                    id: closePreviewMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.wizardBusy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeCreatePreview()
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 46
                            spacing: 8

                            Repeater {
                                model: root.wizardSteps

                                Rectangle {
                                    id: wizardStepCard
                                    required property string modelData
                                    required property int index
                                    readonly property bool active: root.wizardStep === index
                                    readonly property bool complete: root.wizardStep > index || root.creationStage === "complete"

                                    width: (parent.width - 32) / 5
                                    height: 46
                                    radius: 7
                                    color: active ? Qt.alpha(root.palette.accent, 0.18) : root.palette.panelBackground
                                    border.width: 1
                                    border.color: active ? root.palette.accent : complete ? root.palette.success : root.palette.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: (wizardStepCard.complete ? "✓ " : (wizardStepCard.index + 1) + ". ") + wizardStepCard.modelData
                                        color: wizardStepCard.active ? root.palette.accent : wizardStepCard.complete ? root.palette.success : root.palette.secondaryText
                                        font.pixelSize: root.wizardControlFontSize
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: wizardStepCard.index < root.wizardStep && !root.wizardBusy
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.selectWizardStep(wizardStepCard.index)
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: parent.height - 112
                            spacing: 14

                            Rectangle {
                                width: 320
                                height: parent.height
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 9

                                    Text {
                                        width: parent.width
                                        text: (root.wizardStep + 1) + ". " + root.wizardSteps[root.wizardStep]
                                        color: root.palette.accent
                                        font.pixelSize: root.wizardHeadingFontSize
                                        font.bold: true
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 0
                                        width: parent.width
                                        height: root.storageReady() ? 190 : 330
                                        radius: 7
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.storageReady() ? root.palette.success : root.storageSetupStage === "failed" ? root.palette.danger : root.palette.warning

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            Text {
                                                width: parent.width
                                                text: root.storageReady() ? "Bastille storage ready" : "Choose a ZFS pool"
                                                color: root.palette.primaryText
                                                font.pixelSize: root.wizardHeadingFontSize
                                                font.bold: true
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.storageReady() ? "Bastille will own the release and jail datasets beneath its installation root." : "Bastille will use its conventional “bastille” dataset. Other datasets are left alone."
                                                color: root.palette.secondaryText
                                                font.pixelSize: root.wizardBodyFontSize
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                visible: root.storageReady()
                                                width: parent.width
                                                text: "✓ " + (root.storageInfo.target_dataset || root.storageInfo.prefix || "/usr/local/bastille")
                                                color: root.palette.success
                                                font.pixelSize: root.wizardBodyFontSize
                                                font.bold: true
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                visible: root.storageReady()
                                                width: parent.width
                                                text: root.storageInfo.initialized || root.bastilleSetup ? "Dataset hierarchy initialized" : "The Userland step will initialize the hierarchy"
                                                color: root.palette.mutedText
                                                font.pixelSize: root.wizardCaptionFontSize
                                                wrapMode: Text.WordWrap
                                            }

                                            Rectangle {
                                                visible: !root.storageReady()
                                                width: parent.width
                                                height: 42
                                                radius: 6
                                                color: storagePoolMouse.containsMouse && root.storagePools().length > 1 ? root.palette.cardHover : root.palette.panelBackground
                                                border.width: 1
                                                border.color: root.selectedStoragePool.length > 0 ? root.palette.accent : root.palette.danger

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: 10

                                                    Text {
                                                        width: parent.width - 58
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.selectedStoragePool.length > 0 ? "Pool: " + root.selectedStoragePool : "No ZFS pool detected"
                                                        color: root.palette.primaryText
                                                        font.pixelSize: root.wizardControlFontSize
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: 58
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        horizontalAlignment: Text.AlignRight
                                                        text: root.storagePools().length > 1 ? "Next ›" : ""
                                                        color: root.palette.accent
                                                        font.pixelSize: root.wizardCaptionFontSize
                                                        font.bold: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: storagePoolMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: root.storagePools().length > 1 && !root.storageSetupRunning
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: root.cycleStoragePool()
                                                }
                                            }

                                            Text {
                                                visible: !root.storageReady()
                                                width: parent.width
                                                text: "Target: " + root.storageTargetDataset()
                                                color: root.palette.mutedText
                                                font.pixelSize: root.wizardCaptionFontSize
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: !root.storageReady()
                                                width: parent.width
                                                text: "Type “" + root.selectedStoragePool + "” to confirm"
                                                color: root.palette.secondaryText
                                                font.pixelSize: root.wizardCaptionFontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: !root.storageReady()
                                                width: parent.width
                                                height: 38
                                                radius: 6
                                                color: root.palette.panelBackground
                                                border.width: 1
                                                border.color: storageConfirmationInput.activeFocus ? root.palette.accent : root.storageConfirmation === root.selectedStoragePool && root.selectedStoragePool.length > 0 ? root.palette.success : root.palette.panelBorder

                                                TextInput {
                                                    id: storageConfirmationInput
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    text: root.storageConfirmation
                                                    enabled: !root.storageSetupRunning && root.selectedStoragePool.length > 0
                                                    color: root.palette.primaryText
                                                    selectionColor: root.palette.accent
                                                    selectedTextColor: root.palette.panelBackground
                                                    font.pixelSize: root.wizardControlFontSize
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    onTextEdited: root.storageConfirmation = text
                                                }
                                            }

                                            Rectangle {
                                                visible: !root.storageReady()
                                                width: parent.width
                                                height: 42
                                                radius: 7
                                                color: storageSetupMouse.enabled ? (storageSetupMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.18)) : root.palette.panelBackground
                                                border.width: 1
                                                border.color: storageSetupMouse.enabled ? root.palette.success : root.palette.panelBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.demoMode ? "Setup Disabled in Demo" : root.storageSetupRunning ? "Configuring Storage…" : "Configure Bastille Storage"
                                                    color: storageSetupMouse.enabled ? root.palette.success : root.palette.mutedText
                                                    font.pixelSize: root.wizardBodyFontSize
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: storageSetupMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: root.canConfigureStorage()
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: root.startStorageSetup()
                                                }
                                            }

                                            Text {
                                                visible: !root.storageReady() && root.storageSetupMessage.length > 0
                                                width: parent.width
                                                text: root.storageSetupMessage
                                                color: root.storageSetupStage === "failed" ? root.palette.danger : root.palette.accent
                                                font.pixelSize: root.wizardCaptionFontSize
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 2
                                        width: parent.width
                                        height: root.networkReady() ? 142 : 248
                                        radius: 7
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.networkReady() ? root.palette.success : root.networkSetupStage === "failed" ? root.palette.danger : root.palette.warning

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 7

                                            Text {
                                                width: parent.width
                                                text: root.networkReady() ? "Jail networking ready" : "Configure private jail networking"
                                                color: root.palette.primaryText
                                                font.pixelSize: root.wizardHeadingFontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: (root.networkInfo.loopback_ready ? "✓" : "!") + " " + (root.networkInfo.loopback_interface || "bastille0") + "   " + (root.networkInfo.nat_ready && root.networkInfo.rdr_anchor_ready && root.networkInfo.filter_anchor_ready ? "✓ PF NAT + anchors" : "! PF NAT + anchors")
                                                color: root.networkReady() ? root.palette.success : root.palette.warning
                                                font.pixelSize: root.wizardBodyFontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: "Uplink: " + (root.networkInfo.external_interface || "not detected") + " • address checked against host routes"
                                                color: root.palette.mutedText
                                                font.pixelSize: root.wizardCaptionFontSize
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: !root.networkReady()
                                                width: parent.width
                                                text: "Type “" + root.previewAddress + "” to confirm"
                                                color: root.palette.secondaryText
                                                font.pixelSize: root.wizardCaptionFontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: !root.networkReady()
                                                width: parent.width
                                                height: 38
                                                radius: 6
                                                color: root.palette.panelBackground
                                                border.width: 1
                                                border.color: networkConfirmationInput.activeFocus ? root.palette.accent : root.networkConfirmation === root.previewAddress && root.previewAddress.length > 0 ? root.palette.success : root.palette.panelBorder

                                                TextInput {
                                                    id: networkConfirmationInput
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    text: root.networkConfirmation
                                                    enabled: !root.networkSetupRunning && root.previewAddress.length > 0
                                                    color: root.palette.primaryText
                                                    selectionColor: root.palette.accent
                                                    selectedTextColor: root.palette.panelBackground
                                                    font.pixelSize: root.wizardControlFontSize
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    onTextEdited: root.networkConfirmation = text
                                                }
                                            }

                                            Rectangle {
                                                visible: !root.networkReady()
                                                width: parent.width
                                                height: 42
                                                radius: 7
                                                color: networkSetupMouse.enabled ? (networkSetupMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.18)) : root.palette.panelBackground
                                                border.width: 1
                                                border.color: networkSetupMouse.enabled ? root.palette.success : root.palette.panelBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.demoMode ? "Setup Disabled in Demo" : root.networkSetupRunning ? "Configuring Networking…" : "Configure Jail Networking"
                                                    color: networkSetupMouse.enabled ? root.palette.success : root.palette.mutedText
                                                    font.pixelSize: root.wizardBodyFontSize
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: networkSetupMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: root.canConfigureNetwork()
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: root.startNetworkSetup()
                                                }
                                            }

                                            Text {
                                                visible: !root.networkReady() && root.networkSetupMessage.length > 0
                                                width: parent.width
                                                text: root.networkSetupMessage
                                                color: root.networkSetupStage === "failed" ? root.palette.danger : root.palette.accent
                                                font.pixelSize: root.wizardCaptionFontSize
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Text {
                                        visible: root.wizardStep === 3
                                        width: parent.width
                                        text: "Jail name"
                                        color: root.palette.secondaryText
                                        font.pixelSize: root.wizardBodyFontSize
                                        font.bold: true
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 3
                                        width: parent.width
                                        height: 40
                                        radius: 6
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: previewNameInput.activeFocus ? root.palette.accent : root.palette.panelBorder

                                        TextInput {
                                            id: previewNameInput
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: root.previewName
                                            color: root.palette.primaryText
                                            selectionColor: root.palette.accent
                                            selectedTextColor: root.palette.panelBackground
                                            font.pixelSize: root.wizardControlFontSize
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            onTextEdited: {
                                                root.previewName = text
                                                root.invalidateCreatePlan()
                                            }
                                        }
                                    }

                                    Text {
                                        visible: root.wizardStep === 3
                                        width: parent.width
                                        text: "Outbound access"
                                        color: root.palette.secondaryText
                                        font.pixelSize: root.wizardBodyFontSize
                                        font.bold: true
                                    }

                                    Row {
                                        visible: root.wizardStep === 3
                                        width: parent.width
                                        height: 76
                                        spacing: 6

                                        Repeater {
                                            model: root.outboundPolicyChoices

                                            Rectangle {
                                                id: previewPolicyCard
                                                required property var modelData
                                                readonly property bool selected: root.previewOutboundPolicy === modelData.id

                                                width: (parent.width - 12) / 3
                                                height: parent.height
                                                radius: 7
                                                color: previewPolicyMouse.containsMouse ? root.palette.cardHover : selected ? Qt.alpha(root.palette.accent, 0.16) : root.palette.cardBackground
                                                border.width: 1
                                                border.color: selected ? root.palette.accent : root.palette.panelBorder

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 7
                                                    spacing: 4

                                                    Text {
                                                        width: parent.width
                                                        text: (previewPolicyCard.selected ? "✓ " : "") + previewPolicyCard.modelData.label
                                                        color: previewPolicyCard.selected ? root.palette.accent : root.palette.primaryText
                                                        font.pixelSize: root.wizardBodyFontSize
                                                        font.bold: true
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: previewPolicyCard.modelData.detail
                                                        color: root.palette.mutedText
                                                        font.pixelSize: root.wizardCaptionFontSize
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: previewPolicyMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.chooseOutboundPolicy(previewPolicyCard.modelData.id)
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: root.wizardStep === 1
                                        width: parent.width
                                        text: "FreeBSD release"
                                        color: root.palette.secondaryText
                                        font.pixelSize: root.wizardBodyFontSize
                                        font.bold: true
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 1
                                        width: parent.width
                                        height: 52
                                        z: root.releaseMenuOpen ? 30 : 0
                                        radius: 6
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.releaseMenuOpen ? root.palette.accent : root.palette.panelBorder

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 10

                                            Column {
                                                width: parent.width - 28
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1

                                                Text {
                                                    width: parent.width
                                                    text: root.previewRelease
                                                    color: root.palette.primaryText
                                                    font.pixelSize: root.wizardControlFontSize
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: root.releaseSelectionDetail()
                                                    color: root.palette.mutedText
                                                    font.pixelSize: root.wizardCaptionFontSize
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                width: 28
                                                anchors.verticalCenter: parent.verticalCenter
                                                horizontalAlignment: Text.AlignRight
                                                text: root.releaseMenuOpen ? "⌃" : "⌄"
                                                color: root.palette.accent
                                                font.pixelSize: 14
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.releaseMenuOpen = !root.releaseMenuOpen
                                        }

                                        Rectangle {
                                            visible: root.releaseMenuOpen
                                            x: 0
                                            y: parent.height + 4
                                            width: parent.width
                                            height: Math.min(root.releaseChoices().length * 50 + 8, 164)
                                            z: 40
                                            radius: 7
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.accent

                                            Flickable {
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                contentWidth: width
                                                contentHeight: releaseChoiceColumn.height
                                                clip: true

                                                Column {
                                                    id: releaseChoiceColumn
                                                    width: parent.width

                                                    Repeater {
                                                        model: root.releaseChoices()

                                                        Rectangle {
                                                            id: releaseChoice
                                                            required property var modelData

                                                            width: parent.width
                                                            height: 50
                                                            radius: 5
                                                            color: releaseChoiceMouse.containsMouse ? root.palette.cardHover : "transparent"

                                                            Column {
                                                                anchors.fill: parent
                                                                anchors.margins: 7
                                                                spacing: 2

                                                                Text {
                                                                    width: parent.width
                                                                    text: releaseChoice.modelData.label
                                                                    color: root.palette.primaryText
                                                                    font.pixelSize: root.wizardControlFontSize
                                                                    font.bold: true
                                                                    elide: Text.ElideRight
                                                                }

                                                                Text {
                                                                    width: parent.width
                                                                    text: releaseChoice.modelData.detail
                                                                    color: root.palette.mutedText
                                                                    font.pixelSize: root.wizardCaptionFontSize
                                                                    elide: Text.ElideRight
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: releaseChoiceMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.chooseRelease(releaseChoice.modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 1 && root.previewReleaseCustom
                                        width: parent.width
                                        height: visible ? 40 : 0
                                        radius: 6
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: previewReleaseInput.activeFocus ? root.palette.accent : root.palette.panelBorder

                                        TextInput {
                                            id: previewReleaseInput
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: root.previewRelease
                                            color: root.palette.primaryText
                                            selectionColor: root.palette.accent
                                            selectedTextColor: root.palette.panelBackground
                                            font.pixelSize: root.wizardControlFontSize
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            onTextEdited: {
                                                root.previewRelease = text
                                                root.previewReleaseCustomized = true
                                                root.invalidateCreatePlan()
                                            }
                                        }
                                    }

                                    Text {
                                        visible: root.wizardStep === 1
                                        width: parent.width
                                        text: "Jail userland"
                                        color: root.palette.secondaryText
                                        font.pixelSize: root.wizardBodyFontSize
                                        font.bold: true
                                    }

                                    Row {
                                        visible: root.wizardStep === 1
                                        width: parent.width
                                        height: 74
                                        spacing: 8

                                        Repeater {
                                            model: [
                                                {"id": "thick", "label": "Thick", "detail": "Independent copy • Recommended"},
                                                {"id": "thin", "label": "Thin", "detail": "Shared base • Less disk"}
                                            ]

                                            Rectangle {
                                                id: jailTypeChoice
                                                required property var modelData
                                                readonly property bool selected: root.previewJailType === modelData.id

                                                width: (parent.width - 8) / 2
                                                height: parent.height
                                                radius: 7
                                                color: jailTypeMouse.containsMouse ? root.palette.cardHover : selected ? Qt.alpha(root.palette.accent, 0.16) : root.palette.cardBackground
                                                border.width: 1
                                                border.color: selected ? root.palette.accent : root.palette.panelBorder

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 9
                                                    spacing: 5

                                                    Text {
                                                        width: parent.width
                                                        text: (jailTypeChoice.selected ? "✓ " : "") + jailTypeChoice.modelData.label
                                                        color: jailTypeChoice.selected ? root.palette.accent : root.palette.primaryText
                                                        font.pixelSize: root.wizardControlFontSize
                                                        font.bold: true
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: jailTypeChoice.modelData.detail
                                                        color: root.palette.mutedText
                                                        font.pixelSize: root.wizardCaptionFontSize
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: jailTypeMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.chooseJailType(jailTypeChoice.modelData.id)
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: root.wizardStep === 1
                                        width: parent.width
                                        text: root.bastilleReleases.length > 0 ? "Ready releases: " + root.bastilleReleases.join(", ") : "Selected release will be downloaded before creation."
                                        color: root.bastilleReleases.length > 0 ? root.palette.mutedText : root.palette.warning
                                        font.pixelSize: root.wizardCaptionFontSize
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: root.wizardStep === 2
                                        width: parent.width
                                        text: "IP address / CIDR"
                                        color: root.palette.secondaryText
                                        font.pixelSize: root.wizardBodyFontSize
                                        font.bold: true
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 2
                                        width: parent.width
                                        height: 40
                                        radius: 6
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: previewAddressInput.activeFocus ? root.palette.accent : root.palette.panelBorder

                                        TextInput {
                                            id: previewAddressInput
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: root.previewAddress
                                            color: root.palette.primaryText
                                            selectionColor: root.palette.accent
                                            selectedTextColor: root.palette.panelBackground
                                            font.pixelSize: root.wizardControlFontSize
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            onTextEdited: {
                                                root.previewAddress = text
                                                root.previewAddressCustomized = true
                                                root.networkConfirmation = ""
                                                root.networkSetupStage = "idle"
                                                root.networkSetupMessage = ""
                                                root.networkSetupDetails = ""
                                                root.invalidateCreatePlan()
                                            }
                                        }
                                    }

                                    Row {
                                        visible: root.wizardStep === 3
                                        width: parent.width
                                        height: 44
                                        spacing: 10

                                        Column {
                                            width: parent.width - 104
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: "Start at boot"
                                                color: root.palette.primaryText
                                                font.pixelSize: root.wizardControlFontSize
                                                font.bold: true
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.previewAutostart ? "Bastille boot enabled" : "Adds --no-boot"
                                                color: root.palette.mutedText
                                                font.pixelSize: root.wizardCaptionFontSize
                                            }
                                        }

                                        Rectangle {
                                            width: 94
                                            height: 32
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 16
                                            color: root.previewAutostart ? Qt.alpha(root.palette.success, 0.22) : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.previewAutostart ? root.palette.success : root.palette.panelBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.previewAutostart ? "Enabled" : "Disabled"
                                                color: root.previewAutostart ? root.palette.success : root.palette.secondaryText
                                                font.pixelSize: root.wizardBodyFontSize
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.previewAutostart = !root.previewAutostart
                                                    root.invalidateCreatePlan()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 4
                                        width: parent.width
                                        height: creationConfirmationContent.implicitHeight + 20
                                        radius: 7
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.creationConfirmation === root.previewName ? root.palette.success : root.palette.panelBorder

                                        Column {
                                            id: creationConfirmationContent

                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 10
                                            spacing: 6

                                            Text {
                                                width: parent.width
                                                text: "Type “" + root.previewName + "” to confirm"
                                                color: root.palette.primaryText
                                                font.pixelSize: root.wizardBodyFontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                width: parent.width
                                                height: 40
                                                radius: 6
                                                color: root.palette.panelBackground
                                                border.width: 1
                                                border.color: creationConfirmationInput.activeFocus ? root.palette.accent : root.palette.panelBorder

                                                TextInput {
                                                    id: creationConfirmationInput
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    text: root.creationConfirmation
                                                    enabled: !root.wizardBusy && root.creationStage !== "complete"
                                                    color: root.palette.primaryText
                                                    selectionColor: root.palette.accent
                                                    selectedTextColor: root.palette.panelBackground
                                                    font.pixelSize: root.wizardControlFontSize
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    onTextEdited: root.creationConfirmation = text
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: "Creation may download a release and write jail storage/configuration."
                                                color: root.palette.warning
                                                font.pixelSize: root.wizardCaptionFontSize
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wizardStep > 0 && root.creationStage !== "complete"
                                        width: parent.width
                                        height: 32
                                        radius: 6
                                        color: backWizardMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.panelBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Back"
                                            color: root.palette.secondaryText
                                            font.pixelSize: root.wizardBodyFontSize
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: backWizardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !root.wizardBusy
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.previousWizardStep()
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wizardStep < 4
                                        width: parent.width
                                        height: 46
                                        radius: 7
                                        color: generatePreviewMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.accent, 0.18)
                                        border.width: 1
                                        border.color: root.palette.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.wizardStep === 0 ? "Continue to Userland" : root.wizardStep === 1 ? "Continue to Network" : root.wizardStep === 2 ? "Continue to Config" : "Review Creation Plan"
                                            color: root.palette.primaryText
                                            font.pixelSize: root.wizardControlFontSize
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: generatePreviewMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: root.wizardCanContinue()
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.nextWizardStep()
                                        }
                                    }

                                    Rectangle {
                                        visible: root.wizardStep === 4
                                        width: parent.width
                                        height: 46
                                        radius: 7
                                        color: createJailMouse.enabled ? (createJailMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.18)) : root.palette.cardBackground
                                        border.width: 1
                                        border.color: createJailMouse.enabled ? root.palette.success : root.palette.panelBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.demoMode ? "Creation Disabled in Demo" : root.creationStage === "complete" ? "Jail Created" : root.creationRunning ? (root.creationStage === "bootstrapping" ? "Bootstrapping Release…" : "Creating Jail…") : "Create Jail"
                                            color: createJailMouse.enabled ? root.palette.success : root.palette.mutedText
                                            font.pixelSize: root.wizardControlFontSize
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: createJailMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !root.demoMode && !root.wizardBusy && root.creationStage !== "complete" && root.previewPayload && root.previewPayload.ready && root.creationConfirmation === root.previewName
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.startGuidedCreation()
                                        }
                                    }

                                    Text {
                                        visible: root.wizardStep !== 2
                                        width: parent.width
                                        text: root.demoMode ? "Demo mode shows the full workflow but blocks mutations." : !root.tools.bastille ? "Bastille is not detected; install it before creating a jail." : !root.storageReady() ? (root.storagePools().length > 0 ? "Select a pool and configure Bastille storage." : "Bastille is installed, but no ZFS pool was detected.") : !root.networkReady() ? "Configure the Bastille loopback and BSDRunner PF jail rules." : (root.bastilleSetup ? "Bastille inventory and networking are ready" : "Storage and networking configured; bootstrap will initialize storage") + (root.hostRelease.length > 0 ? " • Host " + root.hostRelease : "")
                                        color: !root.demoMode && root.tools.bastille && root.storageReady() && root.networkReady() ? root.palette.success : root.palette.warning
                                        font.pixelSize: root.wizardCaptionFontSize
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - 334
                                height: parent.height
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.creationStage === "complete" ? root.palette.success : root.creationStage === "failed" || root.previewError.length > 0 ? root.palette.danger : root.previewPayload && root.previewPayload.ready === false ? root.palette.warning : root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    Text {
                                        width: parent.width
                                        text: root.wizardStep < 4 ? root.wizardSteps[root.wizardStep] + " explained" : root.creationStage === "complete" ? "Jail created" : root.creationStage === "failed" ? "Creation needs attention" : root.previewPayload ? root.previewPayload.message : "Checking creation plan…"
                                        color: root.creationStage === "complete" ? root.palette.success : root.creationStage === "failed" || root.previewError.length > 0 ? root.palette.danger : root.previewPayload && root.previewPayload.ready === false ? root.palette.warning : root.palette.accent
                                        font.pixelSize: root.wizardHeadingFontSize
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: parent.height - 34
                                        radius: 7
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.palette.panelBorder

                                        Flickable {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            contentWidth: width
                                            contentHeight: Math.max(height, previewPlanText.contentHeight)
                                            clip: true

                                            TextEdit {
                                                id: previewPlanText
                                                width: parent.width
                                                height: Math.max(parent.height, contentHeight)
                                                text: root.wizardDetailText()
                                                readOnly: true
                                                selectByMouse: true
                                                wrapMode: TextEdit.Wrap
                                                textFormat: TextEdit.PlainText
                                                color: root.creationStage === "failed" || root.previewError.length > 0 ? root.palette.danger : root.palette.primaryText
                                                selectionColor: root.palette.accent
                                                selectedTextColor: root.palette.panelBackground
                                                font.family: "monospace"
                                                font.pixelSize: root.wizardPlanFontSize
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
