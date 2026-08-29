pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: root

  property var shell: null
  readonly property var bar: shell && shell.bar ? shell.bar : null
  readonly property string appClass: "org.omarchy.herdrdrop"
  readonly property string specialName: "special:herdrdrop"

  property bool panelVisible: false
  property string activeScreenName: ""
  property var panelGeometry: null
  property var monitorIpcRecords: []
  property var clientRecords: []
  property var anchorRecords: []
  property bool popoutRegistered: false
  property bool clientQueryPending: false
  property real connectionReveal: panelVisible ? 1 : 0

  visible: false
  width: 0
  height: 0

  Behavior on connectionReveal {
    NumberAnimation {
      duration: root.panelVisible ? 160 : 120
      easing.type: root.panelVisible ? Easing.OutCubic : Easing.InCubic
    }
  }

  function monitorRecords() {
    const records = []
    const monitors = monitorIpcRecords || []
    for (let index = 0; index < monitors.length; index++)
      records.push({ object: null, ipc: monitors[index] })
    return records
  }

  function monitorName(record) {
    const ipc = record && record.ipc ? record.ipc : null
    const object = record && record.object ? record.object : null
    return String(ipc && ipc.name ? ipc.name
      : object && object.name ? object.name : "")
  }

  function monitorSpecial(record) {
    const special = record && record.ipc
      ? record.ipc.specialWorkspace : null
    return special && typeof special === "object"
      ? String(special.name || "") : String(special || "")
  }

  function vectorPair(value) {
    if (!value) return null
    if (value.length !== undefined && value.length >= 2)
      return [Number(value[0]), Number(value[1])]
    if (value.x !== undefined && value.y !== undefined)
      return [Number(value.x), Number(value.y)]
    return null
  }

  function windowGeometry(record) {
    if (!record || !record.ipc) return null
    const name = monitorName(record)
    const monitorX = Number(record.ipc.x) || 0
    const monitorY = Number(record.ipc.y) || 0
    const monitorId = Number(record.ipc.id)

    try {
      const windows = clientRecords || []
      for (let index = 0; index < windows.length; index++) {
        const ipc = windows[index]
        if (!ipc || String(ipc.class || ipc.initialClass || "") !== appClass)
          continue

        const windowMonitor = ipc.monitor
        if (typeof windowMonitor === "number"
            && isFinite(monitorId) && windowMonitor !== monitorId) continue
        if (typeof windowMonitor === "string"
            && windowMonitor !== "" && windowMonitor !== name) continue

        const at = vectorPair(ipc.at)
        const size = vectorPair(ipc.size)
        if (!at || !size || size[0] <= 0 || size[1] <= 0) continue
        return ({
          x: at[0] - monitorX,
          y: at[1] - monitorY,
          width: size[0],
          height: size[1]
        })
      }
    } catch (_error) {}
    return null
  }

  function setAnchor(owner, screenName, x) {
    if (!owner) return
    const next = []
    for (let index = 0; index < anchorRecords.length; index++) {
      if (anchorRecords[index].owner !== owner) next.push(anchorRecords[index])
    }
    if (String(screenName || "") !== "" && Number(x) > 0)
      next.push({ owner: owner, screen: String(screenName), x: Number(x) })
    anchorRecords = next
    publishConnection()
  }

  function clearAnchor(owner) {
    const next = []
    for (let index = 0; index < anchorRecords.length; index++) {
      if (anchorRecords[index].owner !== owner) next.push(anchorRecords[index])
    }
    anchorRecords = next
    publishConnection()
  }

  function anchorForScreen(name, geometry) {
    for (let index = 0; index < anchorRecords.length; index++) {
      const record = anchorRecords[index]
      if (record.screen === name && record.x > 0) return record.x
    }
    return geometry ? geometry.x + geometry.width / 2 : 0
  }

  function publishConnection() {
    if (!root.bar
        || typeof root.bar.publishConnectedPanel !== "function") return
    if (connectionReveal <= 0.001) {
      if (typeof root.bar.clearConnectedPanel === "function")
        root.bar.clearConnectedPanel(root, activeScreenName)
      if (popoutRegistered
          && typeof root.bar.releasePopout === "function")
        root.bar.releasePopout(root, activeScreenName)
      popoutRegistered = false
      return
    }
    const anchorX = anchorForScreen(activeScreenName, panelGeometry)
    if (!panelGeometry || activeScreenName === "" || anchorX <= 0) return
    root.bar.publishConnectedPanel(root, activeScreenName, anchorX,
      connectionReveal, {
        hostCaret: true,
        cardX: panelGeometry.x,
        cardY: panelGeometry.y,
        cardWidth: panelGeometry.width,
        cardHeight: panelGeometry.height
      })
  }

  function refreshState() {
    const previousScreen = activeScreenName
    let nextScreen = ""
    let nextGeometry = null
    const monitors = monitorRecords()
    for (let index = 0; index < monitors.length; index++) {
      const special = monitorSpecial(monitors[index])
      if (special !== specialName && special !== "herdrdrop") continue
      const geometry = windowGeometry(monitors[index])
      if (!geometry) continue
      nextScreen = monitorName(monitors[index])
      nextGeometry = geometry
      break
    }

    if (nextScreen !== "" && previousScreen !== ""
        && nextScreen !== previousScreen && root.bar) {
      if (typeof root.bar.clearConnectedPanel === "function")
        root.bar.clearConnectedPanel(root, previousScreen)
      if (popoutRegistered
          && typeof root.bar.releasePopout === "function")
        root.bar.releasePopout(root, previousScreen)
      popoutRegistered = false
    }

    activeScreenName = nextScreen
    panelGeometry = nextGeometry
    panelVisible = nextScreen !== "" && nextGeometry !== null

    if (panelVisible && !popoutRegistered
        && root.bar && typeof root.bar.requestPopout === "function") {
      root.bar.requestPopout(root, activeScreenName)
      popoutRegistered = true
    }
    publishConnection()
  }

  function queryClients() {
    if (clientQuery.running) {
      clientQueryPending = true
      return
    }
    clientQuery.running = true
  }

  function handleHyprlandEvent(event) {
    if (!event) return
    const name = String(event.name || "")
    if (["activespecial", "openwindow", "closewindow", "movewindow",
         "movewindowv2", "monitoradded", "monitoraddedv2",
         "monitorremoved"].indexOf(name) >= 0) syncTimer.restart()
  }

  function toggle() {
    if (root.bar) root.bar.run("herdr-drop toggle")
    else Quickshell.execDetached(["herdr-drop", "toggle"])
  }

  function close() {
    if (!panelVisible) return
    if (root.bar) root.bar.run("herdr-drop hide")
    else Quickshell.execDetached(["herdr-drop", "hide"])
  }

  function diagnosticState() {
    return ({
      screen: activeScreenName,
      geometry: panelGeometry,
      visible: panelVisible,
      reveal: connectionReveal,
      anchorX: anchorForScreen(activeScreenName, panelGeometry),
      anchors: anchorRecords.length,
      hasBar: root.bar !== null
    })
  }

  onConnectionRevealChanged: publishConnection()
  onBarChanged: syncTimer.restart()

  Component.onDestruction: {
    if (root.bar && typeof root.bar.clearConnectedPanel === "function")
      root.bar.clearConnectedPanel(root, activeScreenName)
    if (root.bar && typeof root.bar.releasePopout === "function")
      root.bar.releasePopout(root, activeScreenName)
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  IpcHandler {
    target: "io.github.lixenstrand.herdr-drop"
    function refresh(): void { root.refreshState() }
    function state(): string { return JSON.stringify(root.diagnosticState()) }
  }

  Timer {
    id: syncTimer
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.queryClients()
  }

  Timer {
    id: clientQueryRetry
    interval: 50
    onTriggered: root.queryClients()
  }

  Process {
    id: clientQuery
    command: [
      "bash", "-c",
      "jq -s '{monitors:.[0],clients:.[1]}' "
        + "<(hyprctl -j monitors) <(hyprctl -j clients)"
    ]
    stdout: StdioCollector { id: clientOutput }
    onExited: function(exitCode, _exitStatus) {
      if (exitCode === 0) {
        try {
          const parsed = JSON.parse(clientOutput.text || "{}")
          root.monitorIpcRecords = Array.isArray(parsed.monitors)
            ? parsed.monitors : []
          root.clientRecords = Array.isArray(parsed.clients)
            ? parsed.clients : []
        } catch (_error) {
          root.monitorIpcRecords = []
          root.clientRecords = []
        }
      }
      root.refreshState()
      if (root.clientQueryPending) {
        root.clientQueryPending = false
        clientQueryRetry.restart()
      }
    }
  }
}
