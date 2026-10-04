import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "seren.workrave"
    ipcTarget: "seren.workrave"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root

    readonly property bool workraveRunning: hostWidget ? hostWidget.workraveRunning : false
    readonly property bool userActive: hostWidget ? hostWidget.userActive : false
    readonly property int idleSeconds: hostWidget ? hostWidget.idleSeconds : 0
    readonly property string operationMode: hostWidget ? hostWidget.operationMode : "normal"
    readonly property string usageMode: hostWidget ? hostWidget.usageMode : "normal"
    readonly property bool breakActive: hostWidget ? hostWidget.breakActive : false
    readonly property int resetRemaining: hostWidget ? hostWidget.resetRemaining : 0
    readonly property int resetDuration: hostWidget ? hostWidget.resetDuration : 0
    readonly property int activeWorkSuspended: hostWidget ? hostWidget.activeWorkSuspended : 0
    readonly property string microText: hostWidget ? hostWidget.microText : ""
    readonly property int microRemaining: hostWidget ? hostWidget.microRemaining : 0
    readonly property int microLimit: hostWidget ? hostWidget.microLimit : 180
    readonly property string microState: hostWidget ? hostWidget.microState : "none"
    readonly property string restText: hostWidget ? hostWidget.restText : ""
    readonly property int restRemaining: hostWidget ? hostWidget.restRemaining : 0
    readonly property int restLimit: hostWidget ? hostWidget.restLimit : 1800
    readonly property string restState: hostWidget ? hostWidget.restState : "none"
    readonly property string dailyText: hostWidget ? hostWidget.dailyText : ""
    readonly property int dailyRemaining: hostWidget ? hostWidget.dailyRemaining : 0
    readonly property int dailyLimit: hostWidget ? hostWidget.dailyLimit : 14400

    readonly property real microFraction: microLimit > 0 ? Math.max(0.0, Math.min(1.0, 1.0 - (microRemaining / microLimit))) : 0.0
    readonly property real restFraction: restLimit > 0 ? Math.max(0.0, Math.min(1.0, 1.0 - (restRemaining / restLimit))) : 0.0
    readonly property real dailyFraction: dailyLimit > 0 ? Math.max(0.0, Math.min(1.0, 1.0 - (dailyRemaining / dailyLimit))) : 0.0

    function formatIdle(sec) {
        if (sec < 60)
            return sec + "s";
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return m + "m " + s + "s";
    }

    function formatDuration(sec) {
        if (sec <= 0)
            return "0:00";
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        var h = Math.floor(m / 60);
        m = m % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function triggerAction(actionName) {
        if (hostWidget && typeof hostWidget.triggerAction === "function") {
            hostWidget.triggerAction(actionName);
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem || root
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                root.switchPanel(direction);
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Style.space(12)

                Item {
                    width: parent.width
                    implicitHeight: Math.max(heroLabels.implicitHeight, heroGlyph.implicitHeight)

                    Column {
                        id: heroLabels
                        anchors.left: parent.left
                        anchors.right: heroGlyph.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)

                        Text {
                            textFormat: Text.PlainText
                            text: "WORKRAVE"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: {
                                if (!root.workraveRunning)
                                    return "NOT RUNNING";
                                if (root.breakActive)
                                    return (root.microState !== "none" ? "REST ACTIVE · DO NOT TYPE" : "REST BREAK · STEP AWAY");
                                if (root.operationMode === "suspended") {
                                    if (root.resetRemaining > 0)
                                        return "SUSPENDED · " + Math.ceil(root.resetRemaining / 60) + "M REMAINING";
                                    return "SUSPENDED · TIMERS FROZEN";
                                }
                                if (root.operationMode === "quiet") {
                                    if (root.resetRemaining > 0)
                                        return "QUIET MODE · " + Math.ceil(root.resetRemaining / 60) + "M REMAINING";
                                    return "QUIET MODE · POPUPS MUTED";
                                }
                                if (root.usageMode === "reading")
                                    return "READING MODE · VOICE / CONTINUOUS";
                                if (!root.userActive)
                                    return "AWAY · IDLE " + root.formatIdle(root.idleSeconds).toUpperCase();
                                return "ACTIVE · RUNNING";
                            }
                            color: {
                                if (!root.workraveRunning)
                                    return Qt.darker(root.barForeground, 1.5);
                                if (root.breakActive || !root.userActive)
                                    return Color.urgent;
                                return Color.accent;
                            }
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1.1
                        }
                    }

                    Text {
                        id: heroGlyph
                        textFormat: Text.PlainText
                        text: {
                            if (!root.workraveRunning)
                                return "󰅶";
                            if (root.breakActive)
                                return "";
                            if (root.usageMode === "reading")
                                return "󰈙";
                            if (!root.userActive)
                                return "󱫡";
                            if (root.operationMode === "suspended")
                                return "󰏤";
                            if (root.operationMode === "quiet")
                                return "󰂛";
                            return "󰔟";
                        }
                        color: {
                            if (!root.workraveRunning)
                                return Qt.darker(root.barForeground, 1.5);
                            if (root.breakActive || !root.userActive)
                                return Color.urgent;
                            return Color.accent;
                        }
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.display
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Active Break Banner
                BorderSurface {
                    visible: root.breakActive
                    width: parent.width
                    implicitHeight: breakCol.implicitHeight + Style.space(16)
                    radius: Style.cornerRadius
                    color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
                    border.color: Color.urgent
                    border.width: 1

                    Column {
                        id: breakCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space(8)
                        spacing: Style.space(8)

                        Row {
                            spacing: Style.space(8)
                            Text {
                                text: ""
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.title
                                color: Color.urgent
                            }
                            Column {
                                spacing: Style.space(2)
                                Text {
                                    text: root.microState !== "none" ? "Microbreak in progress" : "Rest break in progress"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                    color: root.barForeground
                                }
                                Text {
                                    text: (root.microState !== "none" ? root.microText : root.restText) + " remaining"
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: Color.urgent
                                }
                            }
                        }

                        Row {
                            spacing: Style.space(6)
                            width: parent.width

                            Button {
                                width: (parent.width - Style.space(6)) / 2
                                text: "Skip"
                                iconText: "󰒮"
                                bordered: true
                                tooltipText: "Skip this break and resume work."
                                onClicked: root.triggerAction("skip_current")
                            }

                            Button {
                                width: (parent.width - Style.space(6)) / 2
                                text: "Postpone"
                                iconText: "󰔛"
                                bordered: true
                                tooltipText: "Postpone this break by a few minutes."
                                onClicked: root.triggerAction("postpone_current")
                            }
                        }
                    }
                }

                PanelSeparator {
                    width: parent.width
                }

                // Microbreak
                Item {
                    width: parent.width
                    implicitHeight: timerCol1.implicitHeight

                    Column {
                        id: timerCol1
                        width: parent.width
                        spacing: Style.space(4)

                        Item {
                            width: parent.width
                            implicitHeight: microLabel.implicitHeight

                            Text {
                                id: microLabel
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                text: "  Microbreak"
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: true
                            }

                            Text {
                                textFormat: Text.PlainText
                                anchors.right: parent.right
                                text: (root.microText || "—") + " / " + root.formatDuration(root.microLimit)
                                color: Qt.darker(root.barForeground, 1.2)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Item {
                            width: parent.width
                            implicitHeight: Style.space(6)

                            Rectangle {
                                id: microTrack
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
                            }

                            Rectangle {
                                anchors.left: microTrack.left
                                anchors.verticalCenter: microTrack.verticalCenter
                                height: microTrack.height
                                radius: microTrack.radius
                                color: !root.userActive ? Color.urgent : Color.accent
                                width: Math.max(microTrack.height, microTrack.width * root.microFraction)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }

                // Rest Break
                Item {
                    width: parent.width
                    implicitHeight: timerCol2.implicitHeight

                    Column {
                        id: timerCol2
                        width: parent.width
                        spacing: Style.space(4)

                        Item {
                            width: parent.width
                            implicitHeight: restLabel.implicitHeight

                            Text {
                                id: restLabel
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                text: "󰅶  Rest Break"
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: true
                            }

                            Text {
                                textFormat: Text.PlainText
                                anchors.right: parent.right
                                text: (root.restText || "—") + " / " + root.formatDuration(root.restLimit)
                                color: Qt.darker(root.barForeground, 1.2)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Item {
                            width: parent.width
                            implicitHeight: Style.space(6)

                            Rectangle {
                                id: restTrack
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
                            }

                            Rectangle {
                                anchors.left: restTrack.left
                                anchors.verticalCenter: restTrack.verticalCenter
                                height: restTrack.height
                                radius: restTrack.radius
                                color: !root.userActive ? Color.urgent : Color.accent
                                width: Math.max(restTrack.height, restTrack.width * root.restFraction)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }

                // Daily Limit
                Item {
                    width: parent.width
                    implicitHeight: timerCol3.implicitHeight

                    Column {
                        id: timerCol3
                        width: parent.width
                        spacing: Style.space(4)

                        Item {
                            width: parent.width
                            implicitHeight: dailyLabel.implicitHeight

                            Text {
                                id: dailyLabel
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                text: "󰥔  Daily Limit"
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: true
                            }

                            Text {
                                textFormat: Text.PlainText
                                anchors.right: parent.right
                                text: (root.dailyText || "—") + " / " + root.formatDuration(root.dailyLimit)
                                color: Qt.darker(root.barForeground, 1.2)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Item {
                            width: parent.width
                            implicitHeight: Style.space(6)

                            Rectangle {
                                id: dailyTrack
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
                            }

                            Rectangle {
                                anchors.left: dailyTrack.left
                                anchors.verticalCenter: dailyTrack.verticalCenter
                                height: dailyTrack.height
                                radius: dailyTrack.radius
                                color: !root.userActive ? Color.urgent : Color.accent
                                width: Math.max(dailyTrack.height, dailyTrack.width * root.dailyFraction)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }

                PanelSeparator {
                    width: parent.width
                }

                // Operating Modes
                PanelSectionHeader {
                    text: "OPERATING MODE"
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Normal"
                            iconText: "󰄬"
                            selected: root.operationMode === "normal" && root.usageMode !== "reading"
                            tooltipText: "Timers track mouse/typing. Scheduled break modals prompt you to rest."
                            onClicked: {
                                root.triggerAction("mode_normal");
                                if (root.usageMode === "reading") {
                                    root.triggerAction("usage_normal");
                                }
                            }
                        }

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Reading"
                            iconText: "󰈙"
                            selected: root.usageMode === "reading"
                            tooltipText: "Continuous work timer without mouse or keyboard inputs (voice dictation / reading)."
                            onClicked: root.triggerAction("toggle_reading")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Quiet"
                            iconText: "󰂛"
                            selected: root.operationMode === "quiet"
                            tooltipText: "Mute modals. Timers track in the background, but modals stay suppressed for calls."
                            onClicked: root.triggerAction("mode_quiet")
                        }

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Suspend"
                            iconText: "󰏤"
                            selected: root.operationMode === "suspended"
                            tooltipText: "Freeze all timers while watching videos, eating, or relaxing."
                            onClicked: root.triggerAction("mode_suspended")
                        }
                    }

                    // Timed duration chips (visible when in Suspended or Quiet mode)
                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        visible: root.operationMode === "suspended" || root.operationMode === "quiet"

                        Button {
                            width: (parent.width - Style.space(18)) / 4
                            text: "30m"
                            selected: root.resetDuration === 30
                            fontSize: Style.font.caption
                            tooltipText: "Set timed " + root.operationMode + " for 30 minutes. Auto-resumes afterward."
                            onClicked: root.triggerAction("timed_" + root.operationMode + "_30")
                        }

                        Button {
                            width: (parent.width - Style.space(18)) / 4
                            text: "1h"
                            selected: root.resetDuration === 60
                            fontSize: Style.font.caption
                            tooltipText: "Set timed " + root.operationMode + " for 1 hour. Auto-resumes afterward."
                            onClicked: root.triggerAction("timed_" + root.operationMode + "_60")
                        }

                        Button {
                            width: (parent.width - Style.space(18)) / 4
                            text: "2h"
                            selected: root.resetDuration === 120
                            fontSize: Style.font.caption
                            tooltipText: "Set timed " + root.operationMode + " for 2 hours. Auto-resumes afterward."
                            onClicked: root.triggerAction("timed_" + root.operationMode + "_120")
                        }

                        Button {
                            width: (parent.width - Style.space(18)) / 4
                            text: "All Day"
                            selected: root.resetDuration === 0
                            fontSize: Style.font.caption
                            tooltipText: "Set " + root.operationMode + " indefinitely. Protected by work watchdog."
                            onClicked: root.triggerAction("mode_" + root.operationMode)
                        }
                    }

                    // Auto-reset banner when timed mode is active
                    BorderSurface {
                        visible: root.resetRemaining > 0 && (root.operationMode === "suspended" || root.operationMode === "quiet")
                        width: parent.width
                        implicitHeight: timerResetRow.implicitHeight + Style.space(10)
                        radius: Style.cornerRadius
                        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
                        border.color: Color.accent
                        border.width: 1

                        Row {
                            id: timerResetRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Style.space(6)
                            spacing: Style.space(4)

                            Text {
                                width: parent.width - Style.space(136)
                                textFormat: Text.PlainText
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: root.barForeground
                                text: "Resumes in " + root.formatDuration(root.resetRemaining)
                            }

                            Button {
                                width: Style.space(60)
                                text: "+15m"
                                fontSize: Style.font.caption
                                tooltipText: "Extend timed mode by 15 minutes."
                                onClicked: root.triggerAction("extend_timed")
                            }

                            Button {
                                width: Style.space(68)
                                text: "Resume"
                                fontSize: Style.font.caption
                                tooltipText: "Return to Normal mode immediately."
                                onClicked: root.triggerAction("mode_normal")
                            }
                        }
                    }

                    // Watchdog alert if typing detected while suspended
                    Text {
                        visible: root.activeWorkSuspended > 60 && (root.operationMode === "suspended" || root.operationMode === "quiet")
                        width: parent.width
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: Color.urgent
                        text: "󱫡 Active typing detected: " + Math.floor(root.activeWorkSuspended / 60) + "m / 30m before auto-resume."
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(root.barForeground, 1.4)
                        text: {
                            if (root.operationMode === "suspended")
                                return "Suspended: Timers frozen. Active work watchdog auto-resumes after 30m of typing.";
                            if (root.operationMode === "quiet")
                                return "Quiet: Background tracking with muted popups. Auto-resumes if timed.";
                            if (root.usageMode === "reading")
                                return "Reading: Continuous timer for Wispr Flow dictation. Auto-resets on idle.";
                            return "Normal: Timers track active input and prompt breaks on schedule.";
                        }
                    }
                }

                PanelSeparator {
                    width: parent.width
                }

                // Quick Actions
                PanelSectionHeader {
                    text: "ACTIONS & TOOLS"
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Rest Break"
                            iconText: "󰅶"
                            tooltipText: "Start an immediate rest break right now."
                            onClicked: {
                                root.triggerAction("restbreak");
                                root.close();
                            }
                        }

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Exercises"
                            iconText: "󰋪"
                            tooltipText: "Open guided exercise routines (neck, eyes, shoulders)."
                            onClicked: {
                                root.triggerAction("exercises");
                                root.close();
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Statistics"
                            iconText: "󰄫"
                            tooltipText: "View break statistics and computer usage history."
                            onClicked: {
                                root.triggerAction("statistics");
                                root.close();
                            }
                        }

                        Button {
                            width: (parent.width - Style.space(6)) / 2
                            text: "Settings"
                            iconText: "󰒓"
                            tooltipText: "Open Workrave Preferences window."
                            onClicked: {
                                root.triggerAction("preferences");
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
