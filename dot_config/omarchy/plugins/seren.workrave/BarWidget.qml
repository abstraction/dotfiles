import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "seren.workrave"

    property bool workraveRunning: false
    property bool userActive: false
    property int idleSeconds: 0
    property string operationMode: "normal"
    property string microText: ""
    property int microRemaining: 0
    property int microLimit: 180
    property string microState: "none"
    property string restText: ""
    property int restRemaining: 0
    property int restLimit: 2700
    property string restState: "none"
    property string dailyText: ""
    property int dailyRemaining: 0
    property int dailyLimit: 14400

    // Display format: 0 = next imminent break, 1 = dual (micro + rest), 2 = icon only
    property int formatIndex: setting("format", 0)

    readonly property bool breakActive: microState !== "none" || restState !== "none"
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
            return "󰏤 Suspended";
        }
        if (operationMode === "quiet") {
            return "󰂛 Quiet";
        }
        if (formatIndex === 2) {
            return !userActive ? "󱫡" : "󰅶";
        }
        if (formatIndex === 1) {
            var m = microText || "—";
            var r = restText || "—";
            var mIcon = !userActive ? "󱫡 " : "󰈊 ";
            return mIcon + m + "  󰅶 " + r;
        }
        // formatIndex === 0 (auto next break)
        var t = nextBreakText;
        return t !== "" ? (nextBreakIcon + " " + t) : nextBreakIcon;
    }

    readonly property string tooltipText: {
        if (!workraveRunning) {
            return "Workrave · Not running\nClick to launch Workrave";
        }
        var status = userActive ? "Active (running)" : ("Halted (idle " + formatIdle(idleSeconds) + ")");
        var mode = operationMode.charAt(0).toUpperCase() + operationMode.slice(1);
        var lines = ["Workrave · " + status, "• Microbreak: " + (microText || "—"), "• Rest break: " + (restText || "—"), "• Daily limit: " + (dailyText || "—"), "• Mode: " + mode, "", "Left-click: Details · Right-click: Toggle view · Middle-click: Rest break"];
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
                userActive = false;
                return;
            }
            operationMode = data.mode || "normal";
            userActive = data.user_active === true;
            idleSeconds = data.idle_seconds || 0;

            if (data.micro) {
                microText = data.micro.text || "";
                microRemaining = data.micro.remaining || 0;
                microLimit = data.micro.limit || 180;
                microState = data.micro.state || "none";
            }
            if (data.rest) {
                restText = data.rest.text || "";
                restRemaining = data.rest.remaining || 0;
                restLimit = data.rest.limit || 2700;
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

    Process {
        id: actionProc
        command: []
    }

    Process {
        id: monitorProc
        command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/seren.workrave/workrave-monitor.py"]
        running: true
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
