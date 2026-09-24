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

  property date displayDate: clock.date

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

  // ---- Calendar popup. Shape contract for shell.summon/hide/toggle
  //      routing: Bar.findPanelWidget requires open/close/opened on the
  //      bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function toggleWeekStart() {
    if (panelLoader.item) panelLoader.item.toggleWeekStart()
  }

  // The clock fills more slot than it paints a mark for, at both
  // orientations: horizontally it is a text label in a padded slot, so the
  // dot takes the label width; vertically it is a stack of icon-sized lines,
  // so the dot takes one line — the same mark every icon widget gets, rather
  // than a rule running the height of the whole stack.
  readonly property real openPanelIndicatorWidth: root.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: root.vertical ? button.implicitWidth : button.implicitWidth + (lifeBarItem.visible ? lifeBarItem.anchors.leftMargin + lifeBarItem.width + Style.space(20) : 0)
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "seren.clock"

    function refresh(): void { root.broadcast("refresh") }
    function cycleFormat(): void { root.cycleFormat() }
    function toggleWeekStart(): void { root.toggleWeekStart() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-menu-timezone") }
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3
            ? button.fontSize * 0.9
            : button.fontSize
          color: button.foreground
        }
      }
    }
  }

  readonly property date startDate: setting("startDate", "") === "" ? new Date("2026-09-23T00:00:00") : new Date(setting("startDate", ""))
  readonly property int daysEndured: Math.max(0, Math.floor((root.displayDate - startDate) / (1000 * 60 * 60 * 24)))
  readonly property int totalDays: 365
  readonly property real progress: Math.min(1.0, daysEndured / totalDays)

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
      spacing: Style.space(8)

      // The Kintsugi/Gold Accumulation Line
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
          color: "#D4AF37" // Liquid Gold
          
          // Glowing leading edge (The Spark)
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(6)
            height: Style.space(6)
            radius: width / 2
            color: "#FFFACD" // Radiant Yellow
            
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              NumberAnimation { to: 0.3; duration: 2000; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
            }
          }
        }
      }
      
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "DAY " + (root.daysEndured + 1) + " OF 365"
        color: "#D4AF37"
        font.family: root.bar ? root.bar.fontFamily : "sans-serif"
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
        font.bold: true
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "•"
        color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.4)
        font.family: root.bar ? root.bar.fontFamily : "sans-serif"
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: (root.totalDays - (root.daysEndured + 1)) + " LEFT"
        color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.5)
        font.family: root.bar ? root.bar.fontFamily : "sans-serif"
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
        font.bold: true
      }
    }
    
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.togglePanel()
    }
  }

  Rectangle {
    visible: !root.vertical && opacity > 0
    opacity: root.opened ? 0.9 : 0
    color: Color.accent
    radius: Math.min(width, height) / 2
    width: button.labelWidth
    height: Style.space(2)
    x: button.x + (button.width - width) / 2
    y: root.bar && root.bar.position === "top" ? parent.height - height - Style.space(2) : Style.space(2)
    z: 50
    Behavior on opacity {
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
  }
}
