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
    readonly property string microText: hostWidget ? hostWidget.microText : ""
    readonly property int microRemaining: hostWidget ? hostWidget.microRemaining : 0
    readonly property int microLimit: hostWidget ? hostWidget.microLimit : 180
    readonly property string restText: hostWidget ? hostWidget.restText : ""
    readonly property int restRemaining: hostWidget ? hostWidget.restRemaining : 0
    readonly property int restLimit: hostWidget ? hostWidget.restLimit : 2700
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
        contentWidth: panel.fittedContentWidth(Style.space(340))
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
                            text: !root.workraveRunning ? "NOT RUNNING" : (!root.userActive ? ("HALTED · IDLE " + root.formatIdle(root.idleSeconds).toUpperCase()) : (root.operationMode === "suspended" ? "SUSPENDED" : (root.operationMode === "quiet" ? "QUIET MODE" : "ACTIVE · RUNNING")))
                            color: !root.workraveRunning ? Qt.darker(root.barForeground, 1.5) : (!root.userActive ? Color.urgent : Color.accent)
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1.1
                        }
                    }

                    Text {
                        id: heroGlyph
                        textFormat: Text.PlainText
                        text: !root.workraveRunning ? "󰅶" : (!root.userActive ? "󱫡" : (root.operationMode === "suspended" ? "󰏤" : "󰔟"))
                        color: !root.workraveRunning ? Qt.darker(root.barForeground, 1.5) : (!root.userActive ? Color.urgent : Color.accent)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.display
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                PanelSeparator {
                    width: parent.width
                }

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
                                text: "󰈊  Microbreak"
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

                Row {
                    spacing: Style.space(6)

                    Button {
                        text: "Normal"
                        iconText: "󰄬"
                        selected: root.operationMode === "normal"
                        onClicked: root.triggerAction("mode_normal")
                    }

                    Button {
                        text: "Quiet"
                        iconText: "󰂛"
                        selected: root.operationMode === "quiet"
                        onClicked: root.triggerAction("mode_quiet")
                    }

                    Button {
                        text: "Suspend"
                        iconText: "󰏤"
                        selected: root.operationMode === "suspended"
                        onClicked: root.triggerAction("mode_suspended")
                    }
                }

                Row {
                    spacing: Style.space(6)

                    Button {
                        text: "Rest Break"
                        iconText: "󰅶"
                        onClicked: {
                            root.triggerAction("restbreak");
                            root.close();
                        }
                    }

                    Button {
                        text: "Settings"
                        iconText: "󰒓"
                        onClicked: {
                            root.triggerAction("preferences");
                            root.close();
                        }
                    }

                    Button {
                        text: "Window"
                        iconText: "󰍹"
                        onClicked: {
                            root.triggerAction("open");
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
