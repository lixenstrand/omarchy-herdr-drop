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
  readonly property var herdrStatus: connector && connector.herdrStatus
    ? connector.herdrStatus : ({
      available: false,
      loading: true,
      focusedWorkspace: "",
      detail: "Läser Herdr-status…",
      summary: ""
    })
  readonly property bool hasWorkingAgents: connector
    && connector.hasWorkingAgents === true
  readonly property bool needsAttention: connector
    && connector.needsAttention === true
  readonly property bool motionEnabled:
    root.setting("animateSheep", true) !== false
      && Quickshell.env("OMARCHY_REDUCE_MOTION") !== "1"
  readonly property string statusTooltip: {
    const action = root.opened ? "Stäng Herdr Drop" : "Öppna Herdr Drop"
    const workspace = String(root.herdrStatus.focusedWorkspace || "")
    const firstLine = workspace !== ""
      ? action + " · " + workspace + " fokuserad" : action
    const lines = [firstLine, String(root.herdrStatus.detail || "")]
    const summary = String(root.herdrStatus.summary || "")
    if (summary !== "") lines.push(summary)
    return lines.join("\n")
  }

  property bool componentReady: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function syncAnchor() {
    if (connector && typeof connector.setAnchor === "function")
      connector.setAnchor(root, screenName, anchorCenterX)
  }

  function togglePanel() {
    if (connector && typeof connector.queryHerdrStatus === "function")
      connector.queryHerdrStatus()
    if (connector && typeof connector.toggle === "function") connector.toggle()
    else if (root.bar) root.bar.run("herdr-drop toggle")
  }

  function resetSheepMotion() {
    sheepLift.y = 0
    sheepScale.xScale = 1
    sheepScale.yScale = 1
    motionLayer.opacity = 1
  }

  function animateOpen() {
    openingMotion.stop()
    closingMotion.stop()
    resetSheepMotion()
    if (motionEnabled) openingMotion.start()
  }

  function animateClose() {
    openingMotion.stop()
    closingMotion.stop()
    resetSheepMotion()
    if (motionEnabled) closingMotion.start()
  }

  function close() {
    if (opened && connector && typeof connector.close === "function")
      connector.close()
  }

  onConnectorChanged: {
    syncAnchor()
    if (connector && typeof connector.queryHerdrStatus === "function")
      connector.queryHerdrStatus()
  }
  onAnchorCenterXChanged: syncAnchor()
  onScreenNameChanged: syncAnchor()
  onOpenedChanged: {
    if (!componentReady) return
    if (opened) animateOpen()
    else animateClose()
  }
  onMotionEnabledChanged: if (!motionEnabled) resetSheepMotion()

  Component.onCompleted: {
    componentReady = true
    syncAnchor()
  }
  Component.onDestruction: {
    if (connector && typeof connector.clearAnchor === "function")
      connector.clearAnchor(root)
  }

  TransformWatcher {
    id: anchorWatcher
    a: root.anchorWindow ? root.anchorWindow.contentItem : null
    b: button
  }

  Item {
    id: motionLayer
    anchors.fill: parent
    opacity: 1

    transform: [
      Translate {
        id: sheepLift
        y: 0
      },
      Scale {
        id: sheepScale
        origin.x: motionLayer.width / 2
        origin.y: motionLayer.height / 2
        xScale: 1
        yScale: 1
      }
    ]

    Ui.BarIconButton {
      id: button
      anchors.fill: motionLayer
      bar: root.bar
      text: "󰳆"
      active: root.opened || root.hasWorkingAgents
      tooltipText: root.statusTooltip
      onPressed: root.togglePanel()
      onTooltipHoveredChanged: {
        if (button.tooltipHovered && root.connector
            && typeof root.connector.queryHerdrStatus === "function")
          root.connector.queryHerdrStatus()
      }
      onTooltipTextChanged: {
        if (button.tooltipHovered && button.bar)
          button.bar.showTooltip(button, button.tooltipText)
      }
    }

    Rectangle {
      width: Math.max(4, Math.round(button.opticalSize * 0.25))
      height: width
      radius: width / 2
      x: Math.round(parent.width / 2 + button.opticalSize / 2 - width)
      y: Math.round(parent.height / 2 - button.opticalSize / 2)
      color: button.activeColor
      visible: root.needsAttention
    }
  }

  SequentialAnimation {
    id: openingMotion
    ParallelAnimation {
      NumberAnimation {
        target: sheepLift
        property: "y"
        from: 0
        to: -3
        duration: 80
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: sheepScale
        property: "xScale"
        from: 1
        to: 0.96
        duration: 80
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: sheepScale
        property: "yScale"
        from: 1
        to: 1.06
        duration: 80
        easing.type: Easing.OutCubic
      }
    }
    ParallelAnimation {
      NumberAnimation {
        target: sheepLift
        property: "y"
        to: 0
        duration: 120
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: sheepScale
        property: "xScale"
        to: 1
        duration: 120
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: sheepScale
        property: "yScale"
        to: 1
        duration: 120
        easing.type: Easing.OutCubic
      }
    }
  }

  SequentialAnimation {
    id: closingMotion
    ParallelAnimation {
      NumberAnimation {
        target: sheepLift
        property: "y"
        from: 0
        to: -9
        duration: 120
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        target: sheepScale
        property: "xScale"
        from: 1
        to: 0.92
        duration: 120
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        target: sheepScale
        property: "yScale"
        from: 1
        to: 0.92
        duration: 120
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        target: motionLayer
        property: "opacity"
        from: 1
        to: 0
        duration: 120
        easing.type: Easing.InCubic
      }
    }
    PropertyAction { target: sheepLift; property: "y"; value: 0 }
    PropertyAction { target: sheepScale; property: "xScale"; value: 1 }
    PropertyAction { target: sheepScale; property: "yScale"; value: 1 }
    NumberAnimation {
      target: motionLayer
      property: "opacity"
      from: 0
      to: 1
      duration: 80
      easing.type: Easing.OutCubic
    }
  }
}
