import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "omarchy.workspaces"

    readonly property var appLetterOverrides: ({
            "kitty": "K",
            "foot": "F",
            "alacritty": "A",
            "ghostty": "G",
            "brave-origin": "B",
            "brave-browser": "B",
            "brave": "B",
            "firefox": "F",
            "zen": "Z",
            "chromium": "C",
            "google-chrome": "C",
            "chrome": "C",
            "com.microsoft.VSCode": "C",
            "code": "C",
            "vscodium": "C",
            "org.gnome.Nautilus": "F",
            "nautilus": "F",
            "dolphin": "F",
            "thunar": "F",
            "mpv": "M",
            "vlc": "V",
            "spotify": "S",
            "discord": "D",
            "webcord": "D",
            "vesktop": "D",
            "slack": "S",
            "telegram-desktop": "T",
            "telegram": "T",
            "org-jdownloader-update-launcher-JDLauncher": "J",
            "jdownloader": "J",
            "obsidian": "O",
            "gimp": "G",
            "inkscape": "I",
            "blender": "B",
            "steam": "S",
            "libreoffice": "L"
        })

    function workspaceById(id) {
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i];
        }

        return null;
    }

    function workspaceIds() {
        var ids = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        var values = Hyprland.workspaces.values;

        for (var i = 0; i < values.length; i++) {
            var id = values[i].id;
            if (id > 0 && id <= 10 && ids.indexOf(id) === -1)
                ids.push(id);
        }

        ids.sort(function (left, right) {
            return left - right;
        });
        return ids;
    }

    function focusWorkspace(id) {
        if (!root.bar)
            return;
        root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"));
    }

    function unpinnedToplevels(ws) {
        if (!ws || !ws.toplevels || !ws.toplevels.values)
            return [];
        var rawValues = ws.toplevels.values;
        var list = [];
        for (var i = 0; i < rawValues.length; i++) {
            var top = rawValues[i];
            if (!top)
                continue;
            var ipc = top.lastIpcObject || {};
            if (ipc.pinned === true)
                continue;
            if (ipc.hidden === true)
                continue;
            list.push(top);
        }
        list.sort(function (a, b) {
            var aActive = a.activated || (ToplevelManager.activeToplevel && a.wayland === ToplevelManager.activeToplevel);
            var bActive = b.activated || (ToplevelManager.activeToplevel && b.wayland === ToplevelManager.activeToplevel);
            if (aActive && !bActive)
                return -1;
            if (!aActive && bActive)
                return 1;
            var fha = (a.lastIpcObject && typeof a.lastIpcObject.focusHistoryID === "number") ? a.lastIpcObject.focusHistoryID : 9999;
            var fhb = (b.lastIpcObject && typeof b.lastIpcObject.focusHistoryID === "number") ? b.lastIpcObject.focusHistoryID : 9999;
            return fha - fhb;
        });
        return list;
    }

    function isWorkspaceUrgent(ws, toplevels) {
        if (ws && ws.urgent)
            return true;
        if (toplevels) {
            for (var i = 0; i < toplevels.length; i++) {
                if (toplevels[i] && toplevels[i].urgent)
                    return true;
            }
        }
        return false;
    }

    function cleanAppName(raw) {
        if (!raw)
            return "";
        var str = String(raw).trim();
        var dotParts = str.split(".");
        if (dotParts.length > 1) {
            str = dotParts[dotParts.length - 1];
        }
        var dashParts = str.split("-");
        if (dashParts.length > 1) {
            str = dashParts[dashParts.length - 1];
        }
        return str;
    }

    function appLetterForToplevel(top) {
        if (!top)
            return "";
        var ipc = top.lastIpcObject || {};
        var rawClass = (ipc["class"] || ipc["initialClass"] || (top.wayland ? top.wayland.appId : "") || "").trim();

        if (root.appLetterOverrides[rawClass])
            return root.appLetterOverrides[rawClass];

        var lowerClass = rawClass.toLowerCase();
        if (root.appLetterOverrides[lowerClass])
            return root.appLetterOverrides[lowerClass];

        var cleaned = cleanAppName(rawClass);
        var lowerCleaned = cleaned.toLowerCase();
        if (root.appLetterOverrides[lowerCleaned])
            return root.appLetterOverrides[lowerCleaned];

        var candidate = cleaned || rawClass || top.title || "";
        for (var i = 0; i < candidate.length; i++) {
            var ch = candidate[i];
            if (/[a-zA-Z0-9]/.test(ch)) {
                return ch.toUpperCase();
            }
        }
        return "";
    }

    function superscriptCount(count) {
        if (count <= 1)
            return "";
        var map = {
            "0": "\u2070",
            "1": "\u00B9",
            "2": "\u00B2",
            "3": "\u00B3",
            "4": "\u2074",
            "5": "\u2075",
            "6": "\u2076",
            "7": "\u2077",
            "8": "\u2078",
            "9": "\u2079"
        };
        var str = String(count);
        var res = "";
        for (var i = 0; i < str.length; i++) {
            var d = str[i];
            res += (map[d] || "+");
        }
        return res;
    }

    function workspaceLabel(wsId, toplevels) {
        var baseNum = (wsId === 10 ? "0" : String(wsId));
        if (!toplevels || toplevels.length === 0)
            return baseNum;

        var primary = toplevels[0];
        var letter = root.appLetterForToplevel(primary);
        var countSuffix = root.superscriptCount(toplevels.length);

        if (!letter)
            return baseNum + countSuffix;

        return baseNum + ":" + letter + countSuffix;
    }

    function workspaceTooltip(wsId, toplevels) {
        var base = "Workspace " + wsId;
        if (!toplevels || toplevels.length === 0)
            return base + " (empty)";
        var primary = toplevels[0];
        var title = primary.title || (primary.wayland ? primary.wayland.title : "") || (primary.lastIpcObject ? primary.lastIpcObject["class"] : "");
        var countMsg = toplevels.length > 1 ? (" (" + toplevels.length + " windows)") : "";
        return base + ": " + title + countMsg;
    }

    readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

    implicitWidth: grid.implicitWidth + trailingGap
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.rightMargin: root.trailingGap
        columns: root.vertical ? 1 : root.workspaceIds().length
        columnSpacing: root.vertical ? 0 : Style.space(1)
        rowSpacing: root.vertical ? Style.space(2) : 0

        Repeater {
            model: root.workspaceIds()

            RowLayout {
                id: delegateRoot
                required property int modelData
                spacing: 0

                Rectangle {
                    visible: delegateRoot.modelData === 7 && !root.vertical
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.barSize * 0.4
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Style.space(4)
                    Layout.rightMargin: Style.space(4)
                    color: root.bar ? root.bar.barForeground : Color.foreground
                    opacity: 0.3
                }

                WidgetButton {
                    id: button
                    readonly property var workspace: root.workspaceById(delegateRoot.modelData)
                    readonly property var toplevels: root.unpinnedToplevels(workspace)
                    readonly property bool occupied: toplevels.length > 0
                    readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === delegateRoot.modelData
                    readonly property bool urgent: root.isWorkspaceUrgent(workspace, toplevels)

                    bar: root.bar
                    text: root.workspaceLabel(delegateRoot.modelData, toplevels)
                    tooltipText: root.workspaceTooltip(delegateRoot.modelData, toplevels)
                    active: focused || urgent
                    activeColor: urgent ? Color.urgent : Color.accent
                    opacity: occupied || focused || urgent ? 1 : 0.5
                    horizontalMargin: 6
                    verticalPadding: 6
                    fixedWidth: root.vertical ? root.barSize : -1
                    fixedHeight: root.barSize
                    Layout.minimumWidth: root.vertical ? root.barSize : Style.space(20)
                    Layout.preferredHeight: root.barSize
                    onPressed: function () {
                        root.focusWorkspace(delegateRoot.modelData);
                    }
                }
            }
        }
    }
}
