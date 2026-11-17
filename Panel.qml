pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "aitor.home-browser"
  ipcTarget: moduleName
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property string homePath: Quickshell.env("HOME") || "/"
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("backend.py")).replace(/^file:\/\//, ""))
  property string currentPath: homePath
  property string parentPath: homePath
  property string requestedPath: homePath
  property string errorKey: ""
  property var entries: []
  property var history: []
  property bool hiddenFiles: false
  property bool truncated: false
  property bool goingBack: false
  property bool gotResponse: false
  property string addressText: homePath
  readonly property color foreground: Commons.Color.foreground
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function navigate(path, back) {
    if (reader.running) return
    goingBack = back === true
    requestedPath = path
    errorKey = ""
    gotResponse = false
    reader.command = ["python3", helper, requestedPath, currentPath, hiddenFiles ? "true" : "false"]
    reader.running = true
  }
  function goBack() {
    if (history.length) navigate(history[history.length - 1], true)
  }
  function openFile(path) {
    // Fully encoded file URL: names containing #, %, ?, spaces or markup stay literal.
    Qt.openUrlExternally("file://" + path.split("/").map(encodeURIComponent).join("/"))
    root.close()
  }
  onOpenedChanged: if (opened) {
    // Every opening starts in the current user's home directory.
    if (!reader.running) { history = []; navigate(homePath, false) }
  }

  ShellIpc {
    target: "aitor.home-browser.navigation"
    function go(path: string): void { root.navigate(path, false) }
    function back(): void { root.goBack() }
    function status(): string {
      return JSON.stringify({path: root.currentPath, count: root.entries.length, error: root.errorKey, busy: reader.running})
    }
  }

  Process {
    id: reader
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          if (text.length > 8000000) throw new Error("Oversized directory")
          var data = JSON.parse(text)
          root.gotResponse = true
          if (data.error) {
            root.errorKey = ["permission", "missing", "invalid"].indexOf(data.error) >= 0 ? data.error : "invalid"
            return
          }
          if (typeof data.path !== "string" || typeof data.parent !== "string" ||
              !Array.isArray(data.entries) || data.entries.length > 5000) throw new Error("Invalid directory")
          for (var entry of data.entries) {
            if (typeof entry.name !== "string" || entry.name.length > 4096 ||
                typeof entry.path !== "string" || entry.path.length > 8192 ||
                typeof entry.directory !== "boolean") throw new Error("Invalid entry")
          }
          if (root.goingBack) root.history = root.history.slice(0, -1)
          else if (data.path !== root.currentPath) root.history = root.history.concat([root.currentPath])
          root.currentPath = data.path
          root.parentPath = data.parent
          root.addressText = data.path
          root.entries = data.entries
          root.truncated = data.truncated === true
        } catch (e) { root.errorKey = "invalid" }
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || !root.gotResponse) root.errorKey = "invalid"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf07b"
    tooltipText: strings.t("title")
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent ? panel.loadedContent.addressField : null
    contentWidth: panel.fittedContentWidth(Style.space(640))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)
    content: Item {
      id: body
      property alias addressField: address
      implicitHeight: Math.min(Style.space(540), Math.max(Style.space(200), panel.availableCardHeight - panel.verticalContentInset))
      Keys.onEscapePressed: root.close()
      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)
        Text {
          textFormat: Text.PlainText
          text: strings.t("title")
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(4)
          Button { Layout.fillWidth: true; text: strings.t("back"); tooltipText: strings.t("back"); focusable: true; enabled: !reader.running && root.history.length > 0; opacity: enabled ? 1 : 0.4; onClicked: root.goBack() }
          Button { Layout.fillWidth: true; text: strings.t("up"); tooltipText: strings.t("up"); focusable: true; enabled: !reader.running && root.currentPath !== "/"; opacity: enabled ? 1 : 0.4; onClicked: root.navigate(root.parentPath, false) }
          Button { Layout.fillWidth: true; text: strings.t("home"); tooltipText: strings.t("home"); focusable: true; enabled: !reader.running; onClicked: root.navigate(root.homePath, false) }
          Item { Layout.fillWidth: true }
          Button {
            Layout.fillWidth: true; text: strings.t("hidden"); tooltipText: strings.t("hidden"); focusable: true; selected: root.hiddenFiles; enabled: !reader.running
            onClicked: { root.hiddenFiles = !root.hiddenFiles; root.navigate(root.currentPath, false) }
          }
          Button { iconText: "\uf021"; tooltipText: strings.t("refresh"); focusable: true; enabled: !reader.running; onClicked: root.navigate(root.currentPath, false) }
        }
        RowLayout {
          Layout.fillWidth: true
          TextField {
            id: address
            Layout.fillWidth: true
            text: root.addressText
            placeholderText: strings.t("address")
            // Filesystem paths retain their left-to-right order in RTL layouts.
            LayoutMirroring.enabled: false
            horizontalAlignment: TextInput.AlignLeft
            selectByMouse: true
            maximumLength: 8192
            enabled: !reader.running
            onAccepted: root.navigate(text, false)
            Keys.onEscapePressed: root.close()
          }
          Button { text: strings.t("go"); focusable: true; enabled: !reader.running; onClicked: root.navigate(address.text, false) }
        }
        Text {
          Layout.fillWidth: true
          visible: root.errorKey !== ""
          textFormat: Text.PlainText
          text: root.errorKey ? strings.t(root.errorKey) : ""
          wrapMode: Text.WordWrap
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        ListView {
          id: files
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: root.entries
          enabled: !reader.running
          opacity: reader.running ? 0.5 : 1
          boundsBehavior: Flickable.StopAtBounds
          Controls.ScrollBar.vertical: Controls.ScrollBar {}
          onModelChanged: positionViewAtBeginning()
          delegate: Button {
            required property var modelData
            width: files.width - Style.space(14)
            text: modelData.name
            iconText: modelData.directory ? "\uf07b" : "\uf15b"
            // Button's label and tooltip use Text.PlainText in this shell.
            tooltipText: modelData.name
            leftAlign: true
            focusable: true
            onClicked: modelData.directory ? root.navigate(modelData.path, false) : root.openFile(modelData.path)
          }
          Text {
            anchors.centerIn: parent
            visible: reader.running || (root.entries.length === 0 && root.errorKey === "")
            textFormat: Text.PlainText
            text: reader.running ? strings.t("loading") : strings.t("empty")
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
        Text {
          Layout.fillWidth: true
          visible: root.truncated
          textFormat: Text.PlainText
          text: strings.t("limited").arg(Commons.I18n.formatNumber(5000))
          wrapMode: Text.WordWrap
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        RowLayout {
          Layout.fillWidth: true
          Text {
            textFormat: Text.PlainText
            text: strings.tn("count", root.entries.length).arg(Commons.I18n.formatNumber(root.entries.length))
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Button { Layout.fillWidth: true; text: strings.t("openManager"); tooltipText: strings.t("openManager"); focusable: true; onClicked: root.openFile(root.currentPath) }
        }
      }
    }
  }
}
