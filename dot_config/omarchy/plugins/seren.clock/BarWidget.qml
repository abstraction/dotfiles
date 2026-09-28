import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Date/time label for the bar, and the host for the calendar popup.
//
// Left click reveals the calendar — asking "what is the date?" is what a
// click on a clock means — right click walks the common label formats, and
// middle click opens the timezone picker.
BarWidget {
  id: root
  moduleName: "seren.clock"

  property date displayDate: root.now

  readonly property string configuredFormat: vertical
    ? setting("verticalFormat", "HH\n—\nmm")
    : setting("format", "dddd HH:mm")
  readonly property string configuredAltFormat: vertical
    ? setting("verticalFormatAlt", "dd\nMMM\n'W'ww\n''yy")
    : setting("formatAlt", "d MMMM 'W'ww yyyy")

  readonly property var formatRing: Model.clockFormatRing(configuredFormat, configuredAltFormat, Model.clockFormats(vertical))

  // What the bar shows is what shell.json stores, so a cycled format is the
  // format from then on rather than something that reverts on restart.
  readonly property string activeFormat: configuredFormat
  readonly property string displayText: formatted(displayDate)
  readonly property var verticalLines: displayText.split("\n")

  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), displayDate.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, displayDate.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var current = String(configuredFormat)
    var next = Model.nextClockFormat(formatRing, current)
    if (next === "" || next === current) return

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next

    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function formatted(date) {
    return Qt.formatDateTime(date, activeFormat.replace(/ww/g, Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate())))
  }

  readonly property bool opened: false
  readonly property real openPanelIndicatorWidth: root.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: false

  implicitWidth: root.vertical ? button.implicitWidth : button.implicitWidth + (lifeBarItem.visible ? lifeBarItem.anchors.leftMargin + lifeBarItem.width + Style.space(20) : 0)
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: false
    fixedHeight: -1
    horizontalMargin: 0
    verticalPadding: 0
  }

  property date now: new Date()
  Timer {
    running: true
    repeat: true
    interval: 47
    onTriggered: root.now = new Date()
  }

  readonly property int currentYear: root.now.getFullYear()
  readonly property date startDate: new Date(currentYear, 0, 1)
  readonly property date targetDate: new Date(currentYear, 11, 31, 23, 59, 59)
  readonly property int totalDays: Math.ceil((targetDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24))
  readonly property int daysEndured: Math.max(0, Math.floor((root.displayDate - startDate) / (1000 * 60 * 60 * 24)))
  readonly property real progress: Math.min(1.0, daysEndured / totalDays)
  readonly property real exactDaysLeft: Math.max(0, (targetDate.getTime() - root.now.getTime()) / (1000 * 60 * 60 * 24))
  readonly property string exactDaysLeftStr: exactDaysLeft.toFixed(7)

  Item {
    id: lifeBarItem
    visible: !root.vertical
    anchors.left: button.right
    anchors.leftMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    width: innerRow.implicitWidth
    height: parent.height

    Row {
      id: innerRow
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(12)

      // Past: Days Endured
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "DAY " + (root.daysEndured + 1) + " OF " + root.totalDays
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : "sans-serif"
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
        font.bold: true
      }

      // Present: The Bridge
      Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(80)
        height: Style.space(4)

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.1)
        }

        Rectangle {
          width: Math.max(height, parent.width * root.progress)
          height: parent.height
          radius: height / 2
          color: Color.accent // Dynamic Theme Color
          
          // Glowing leading edge (The Spark)
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height // Exact same size as bar height (no bulge)
            height: parent.height
            radius: height / 2
            color: Qt.lighter(Color.accent, 1.4) // Core spark
            
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              NumberAnimation { to: 0.3; duration: 2000; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
            }
          }
        }
      }

      // Future: Days Left
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.exactDaysLeftStr + " DAYS LEFT"
        color: button.foreground
        font.family: root.bar ? root.bar.fontFamily : "monospace"
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }
    
  }
}
