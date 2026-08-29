pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Ui as Ui

Ui.BarWidget {
  id: root

  moduleName: "io.github.lixenstrand.herdr-drop"

  readonly property var anchorWindow: button.QsWindow.window
  readonly property string screenName: anchorWindow && anchorWindow.screen
    ? String(anchorWindow.screen.name || "") : ""
  readonly property point anchorPosition: {
    anchorWatcher.transform
    if (!anchorWindow) return Qt.point(0, 0)
    return button.mapToItem(anchorWindow.contentItem, 0, 0)
  }
  readonly property real anchorCenterX:
    anchorPosition.x + button.width / 2
  readonly property var connector: root.bar && root.bar.shell
    && typeof root.bar.shell.serviceFor === "function"
    ? root.bar.shell.serviceFor(root.moduleName) : null
  readonly property bool opened: connector
    && connector.panelVisible === true
    && connector.activeScreenName === screenName

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function syncAnchor() {
    if (connector && typeof connector.setAnchor === "function")
      connector.setAnchor(root, screenName, anchorCenterX)
  }

  function togglePanel() {
    if (connector && typeof connector.toggle === "function") connector.toggle()
    else if (root.bar) root.bar.run("herdr-drop toggle")
  }

  function close() {
    if (opened && connector && typeof connector.close === "function")
      connector.close()
  }

  onConnectorChanged: syncAnchor()
  onAnchorCenterXChanged: syncAnchor()
  onScreenNameChanged: syncAnchor()

  Component.onCompleted: syncAnchor()
  Component.onDestruction: {
    if (connector && typeof connector.clearAnchor === "function")
      connector.clearAnchor(root)
  }

  TransformWatcher {
    id: anchorWatcher
    a: root.anchorWindow ? root.anchorWindow.contentItem : null
    b: button
  }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰆍"
    active: root.opened
    tooltipText: root.opened ? "Hide Herdr Drop" : "Open Herdr Drop"
    onPressed: root.togglePanel()
  }
}
