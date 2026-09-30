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
  moduleName: "seren.goal"

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
  readonly property string exactDaysLeftInt: Math.floor(exactDaysLeft).toString()
  readonly property string exactDaysLeftDec: (exactDaysLeft - Math.floor(exactDaysLeft)).toFixed(7).substring(1)

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
      spacing: Style.space(16)

      // 1. The Monolith: High-Contrast Ticking (Left side)
      Row {
        anchors.verticalCenter: parent.verticalCenter
        
        Text {
          anchors.bottom: parent.bottom
          text: root.exactDaysLeftInt
          color: button.foreground
          font.family: root.bar ? root.bar.fontFamily : "sans-serif"
          font.pixelSize: Style.font.bodySmall * 1.75
          font.bold: true
        }
        
        Text {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(1)
          text: root.exactDaysLeftDec
          color: button.foreground // FULL OPACITY, HIGH CONTRAST
          font.family: "monospace"
          font.pixelSize: Style.font.bodySmall * 1.4 // Made bigger to demand attention
          font.bold: true
        }
        
        Text {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(2)
          text: " DAYS LEFT"
          color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.7) // Slightly muted so the numbers pop
          font.family: root.bar ? root.bar.fontFamily : "sans-serif"
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
          font.bold: true
        }
      }

      // 2. The Ledger: De-emphasized, thin slices (Right side)
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)
        
        Repeater {
          model: 12
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(4) // MUCH thinner
            height: Style.space(12) // Cropped down
            radius: 0
            
            readonly property real boxThreshold: index / 12.0
            readonly property real nextBoxThreshold: (index + 1) / 12.0
            readonly property bool isPassed: root.progress >= nextBoxThreshold
            readonly property bool isCurrent: root.progress >= boxThreshold && root.progress < nextBoxThreshold
            
            color: "transparent"
            border.width: Style.space(1)
            border.color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.2) // Very dim borders
            
            // The gradual fill (momentum)
            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              height: parent.height
              width: isPassed ? parent.width : (isCurrent ? parent.width * ((root.progress - boxThreshold) / (1.0 / 12.0)) : 0)
              color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.4) // Muted fill so it doesn't overpower the numbers
            }
          }
        }
      }
    }
    
  }
}
