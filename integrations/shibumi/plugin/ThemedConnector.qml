pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons

// The bridge belongs visually to the foreign Herdr window, not to the bar.
// Use Omarchy's semantic popup roles so both its fill and outline follow the
// active theme (including live theme changes).
PanelWindow {
  id: root

  property var targetScreen: null
  property bool active: false
  property real requestedCenterX: 0
  property real reveal: 0
  property real cardX: 0
  property real cardY: 0
  property real cardWidth: 0

  readonly property real progress:
    Math.max(0, Math.min(1, Number(reveal) || 0))
  readonly property real centerX: Math.max(cardX + 10,
    Math.min(cardX + cardWidth - 10, requestedCenterX))
  readonly property real maxDepth: 5
  readonly property real halfWidth: 6 * progress
  readonly property real depth: maxDepth * progress
  readonly property real tangentControl: 3.75 * progress
  readonly property real tipControl: 1.75 * progress
  readonly property color surfaceColor: Commons.Color.popups.background
  readonly property color strokeColor: Commons.Color.popups.border
  readonly property real strokeWidth: 1

  screen: targetScreen
  visible: active && targetScreen !== null && cardWidth > 0
    && requestedCenterX > 0 && progress > 0.001
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "herdr-drop-themed-connector"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  mask: Region {}

  Rectangle {
    x: Math.round(root.centerX - 13)
    y: root.cardY
    width: 26
    height: 2
    color: root.surfaceColor
    z: 1
  }

  Shape {
    id: connectorShape

    x: Math.round(root.centerX - 13)
    y: root.cardY - root.maxDepth
    width: 26
    height: root.maxDepth + 1
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    layer.enabled: true
    layer.samples: 8
    layer.smooth: true
    layer.mipmap: true
    layer.textureSize: Qt.size(Math.ceil(width * 4), Math.ceil(height * 4))
    z: 2

    readonly property real baseY: root.maxDepth + 0.5
    readonly property real tipY: baseY - root.depth
    readonly property real centerX: width / 2

    ShapePath {
      strokeColor: root.strokeColor
      strokeWidth: root.strokeWidth
      fillColor: root.surfaceColor
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: 0
      startY: connectorShape.baseY
      PathLine {
        x: connectorShape.centerX - root.halfWidth
        y: connectorShape.baseY
      }
      PathCubic {
        x: connectorShape.centerX
        y: connectorShape.tipY
        control1X: connectorShape.centerX - root.tangentControl
        control1Y: connectorShape.baseY
        control2X: connectorShape.centerX - root.tipControl
        control2Y: connectorShape.tipY
      }
      PathCubic {
        x: connectorShape.centerX + root.halfWidth
        y: connectorShape.baseY
        control1X: connectorShape.centerX + root.tipControl
        control1Y: connectorShape.tipY
        control2X: connectorShape.centerX + root.tangentControl
        control2Y: connectorShape.baseY
      }
      PathLine {
        x: connectorShape.width
        y: connectorShape.baseY
      }
    }
  }
}
