import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "seren.workrave"

    property bool workraveRunning: false
    readonly property bool userActive: !waylandIdle.isIdle
    property int idleSeconds: 0
    property string operationMode: "normal"
    property string usageMode: "normal"
    property int resetRemaining: 0
    property int resetDuration: 0
    property int activeWorkSuspended: 0
    property string microText: ""
    property int microRemaining: 0
    property int microLimit: 180
    property string microState: "none"
    property string restText: ""
    property int restRemaining: 0
    property int restLimit: 1800
    property string restState: "none"
    property string dailyText: ""
    property int dailyRemaining: 0
    property int dailyLimit: 14400

    // Display format: 0 = dual (micro + rest), 1 = next imminent break, 2 = icon only
    property int formatIndex: setting("format", 0)

    readonly property bool breakActive: microState !== "none" || restState !== "none" || (microRemaining <= 1 && microRemaining > 0) || (restRemaining <= 1 && restRemaining > 0)
    readonly property bool dimmed: !userActive || !workraveRunning

    function formatIdle(sec) {
        if (sec < 60)
            return sec + "s";
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return m + "m " + s + "s";
    }

    readonly property string nextBreakText: {
        if (microRemaining > 0 && (microRemaining <= restRemaining || restRemaining <= 0)) {
            return microText;
        }
        if (restRemaining > 0) {
            return restText;
        }
        return microText !== "" ? microText : restText;
    }

    readonly property string nextBreakIcon: {
        if (breakActive)
            return "󰅶";
        if (usageMode === "reading")
            return "󰈙";
        if (!userActive)
            return "󱫡";
        if (microRemaining > 0 && (microRemaining <= restRemaining || restRemaining <= 0)) {
            return "󰔟";
        }
        return "󰅶";
    }

    readonly property string displayText: {
        if (!workraveRunning) {
            return "󰅶 Off";
        }
        if (operationMode === "suspended") {
            if (resetRemaining > 0) {
                var mSusp = Math.ceil(resetRemaining / 60);
                return "󰏤 Susp (" + mSusp + "m)";
            }
            return "󰏤 Suspended";
        }
        if (operationMode === "quiet") {
            if (resetRemaining > 0) {
                var mQuiet = Math.ceil(resetRemaining / 60);
                return "󰂛 Quiet (" + mQuiet + "m)";
            }
            return "󰂛 Quiet";
        }
        if (breakActive) {
            if (microState !== "none" || microRemaining <= 1)
                return " Micro (" + (microText || "0s") + ")";
            if (restState !== "none" || restRemaining <= 1)
                return "󰅶 Rest (" + (restText || "0s") + ")";
        }
        var modePrefix = usageMode === "reading" ? "󰈙 " : (!userActive ? "󱫡 " : "");
        if (formatIndex === 2) {
            return modePrefix !== "" ? modePrefix.trim() : "󰅶";
        }
        if (formatIndex === 1) {
            var t = nextBreakText;
            return modePrefix + (t !== "" ? (nextBreakIcon + " " + t) : nextBreakIcon);
        }
        // formatIndex === 0: Dual overview (Micro + Rest)
        var m = microText || "—";
        var r = restText || "—";
        return modePrefix + " " + m + "  󰅶 " + r;
    }

    readonly property string tooltipText: {
        if (!workraveRunning) {
            return "Workrave · Not running\nClick to launch Workrave";
        }
        var status = usageMode === "reading" ? "Reading Mode (Continuous)" : (userActive ? "Active" : ("Away (idle > " + waylandIdle.timeout + "s)"));
        var mode = operationMode.charAt(0).toUpperCase() + operationMode.slice(1);
        if (resetRemaining > 0) {
            mode += " (Auto-resumes in " + Math.ceil(resetRemaining / 60) + "m)";
        }
        var lines = ["Workrave · " + status, "• Micro-break: " + (microText || "—"), "• Rest break:  " + (restText || "—"), "• Daily limit: " + (dailyText || "—"), "• Mode:        " + mode, "• Usage:       " + (usageMode === "reading" ? "Reading / Voice" : "Normal input")];
        if (activeWorkSuspended > 0) {
            lines.push("• Active work while suspended: " + Math.floor(activeWorkSuspended / 60) + "m / 30m");
        }
        lines.push("");
        lines.push("Left-click: Details panel");
        lines.push("Right-click: Cycle display (Dual / Next / Icon)");
        lines.push("Middle-click: Start rest break");
        return lines.join("\n");
    }

    function handleUpdate(line) {
        var raw = String(line).trim();
        if (raw === "")
            return;
        try {
            var data = JSON.parse(raw);
            workraveRunning = data.running === true;
            if (!workraveRunning) {
                return;
            }
            operationMode = data.mode || "normal";
            usageMode = data.usage_mode || "normal";
            idleSeconds = data.idle_seconds || 0;
            resetRemaining = data.reset_remaining || 0;
            resetDuration = data.reset_duration || 0;
            activeWorkSuspended = data.active_work_suspended || 0;

            if (data.micro) {
                microText = data.micro.text || "";
                microRemaining = data.micro.remaining || 0;
                microLimit = data.micro.limit || 180;
                microState = data.micro.state || "none";
            }
            if (data.rest) {
                restText = data.rest.text || "";
                restRemaining = data.rest.remaining || 0;
                restLimit = data.rest.limit || 1800;
                restState = data.rest.state || "none";
            }
            if (data.daily) {
                dailyText = data.daily.text || "";
                dailyRemaining = data.daily.remaining || 0;
                dailyLimit = data.daily.limit || 14400;
            }
        } catch (e) {
            console.warn("Workrave JSON parse error:", e, raw);
        }
    }

    function triggerAction(actionName) {
        actionProc.command = [Quickshell.env("HOME") + "/.config/omarchy/plugins/seren.workrave/workrave-monitor.py", "action", actionName];
        actionProc.running = false;
        actionProc.running = true;
    }

    IdleMonitor {
        id: waylandIdle
        enabled: true
        timeout: 45
    }

    Timer {
        id: activityPingTimer
        interval: 2000
        repeat: true
        running: root.workraveRunning && !waylandIdle.isIdle && !root.breakActive
        onTriggered: {
            if (monitorProc.running) {
                monitorProc.write("activity\n");
            }
        }
    }

    Process {
        id: actionProc
        command: []
    }

    Process {
        id: monitorProc
        command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/seren.workrave/workrave-monitor.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: function (line) {
                root.handleUpdate(line);
            }
        }
    }

    // ---- Panel management ----
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function open() {
        if (panelLoader.item)
            panelLoader.item.open();
    }

    function close() {
        if (panelLoader.item)
            panelLoader.item.close();
    }

    function togglePanel() {
        if (panelLoader.item)
            panelLoader.item.toggle();
    }

    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function closeForPopoutSwitch() {
        if (panelLoader.item)
            panelLoader.item.closeForPopoutSwitch();
    }

    function injectPanel() {
        var target = panelLoader.item;
        if (!target)
            return;
        if ("bar" in target)
            target.bar = root.bar;
        if ("settings" in target)
            target.settings = root.settings;
        if ("anchorItem" in target)
            target.anchorItem = button;
        if ("hostWidget" in target)
            target.hostWidget = root;
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel();
            Qt.callLater(root.injectPanel);
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.displayText
        fontSize: Style.font.body
        active: root.breakActive
        dimmed: root.dimmed
        horizontalMargin: 8
        tooltipText: root.tooltipText

        onPressed: function (b) {
            if (b === Qt.RightButton) {
                root.formatIndex = (root.formatIndex + 1) % 3;
            } else if (b === Qt.MiddleButton) {
                root.triggerAction("restbreak");
            } else {
                if (!root.workraveRunning) {
                    root.triggerAction("open");
                } else {
                    root.togglePanel();
                }
            }
        }
    }
}
