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
  property bool herdrQueryPending: false
  property var herdrStatus: ({
    available: false,
    loading: true,
    workspaces: 0,
    agents: 0,
    working: 0,
    blocked: 0,
    done: 0,
    focusedWorkspace: "",
    detail: "Läser Herdr-status…",
    summary: ""
  })

  readonly property bool hasWorkingAgents:
    Number(herdrStatus.working || 0) > 0
  readonly property bool needsAttention:
    Number(herdrStatus.blocked || 0) > 0
      || Number(herdrStatus.done || 0) > 0

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

  function cleanWorkspaceLabel(value) {
    return String(value || "").replace(/^\[\d+\]\s*/, "").trim()
  }

  function cleanTerminalTitle(value) {
    return String(value || "")
      .replace(/^[^A-Za-z0-9À-ɏ]+/, "").trim()
  }

  function compact(value, maxLength) {
    const text = String(value || "")
    return text.length <= maxLength
      ? text : text.slice(0, Math.max(1, maxLength - 1)) + "…"
  }

  function agentDetail(agent, workspaceLabels) {
    const session = agent && agent.agent_session ? agent.agent_session : null
    const name = String(agent && agent.agent ? agent.agent
      : session && session.agent ? session.agent : "agent")
    const workspace = cleanWorkspaceLabel(
      workspaceLabels[String(agent && agent.workspace_id || "")] || "")
    const title = compact(cleanTerminalTitle(agent
      && (agent.terminal_title_stripped || agent.terminal_title)), 48)
    let detail = name
    if (workspace !== "") detail += " i " + workspace
    if (title !== "" && title.toLowerCase() !== name.toLowerCase())
      detail += " — " + title
    return detail
  }

  function agentStatusDetail(agents, workspaceLabels) {
    const priorities = [
      { status: "blocked", label: "Väntar på dig" },
      { status: "done", label: "Klar" },
      { status: "working", label: "Arbetar" },
      { status: "idle", label: "Redo" },
      { status: "unknown", label: "Okänd status" }
    ]
    for (let priorityIndex = 0;
         priorityIndex < priorities.length; priorityIndex++) {
      const priority = priorities[priorityIndex]
      const matches = []
      for (let agentIndex = 0; agentIndex < agents.length; agentIndex++) {
        if (String(agents[agentIndex].agent_status || "unknown")
            === priority.status) matches.push(agents[agentIndex])
      }
      if (matches.length === 0) continue
      const more = matches.length > 1 ? " +" + (matches.length - 1) : ""
      return priority.label + ": "
        + agentDetail(matches[0], workspaceLabels) + more
    }
    return "Inga upptäckta agenter"
  }

  function statusSummary(workspaceCount, agentCount) {
    const workspaces = workspaceCount === 1
      ? "1 workspace" : workspaceCount + " workspaces"
    let agents = "inga upptäckta agenter"
    if (agentCount === 1) agents = "1 upptäckt agent"
    else if (agentCount > 1) agents = agentCount + " upptäckta agenter"
    return workspaces + " · " + agents
  }

  function applyHerdrSnapshot(payload) {
    const result = payload && payload.result ? payload.result : null
    const snapshot = result && result.snapshot ? result.snapshot : null
    if (!snapshot || typeof snapshot !== "object") return false

    const workspaces = Array.isArray(snapshot.workspaces)
      ? snapshot.workspaces : []
    const agents = Array.isArray(snapshot.agents) ? snapshot.agents : []
    const workspaceLabels = ({})
    let focusedWorkspace = ""
    for (let index = 0; index < workspaces.length; index++) {
      const workspace = workspaces[index] || ({})
      const label = cleanWorkspaceLabel(workspace.label)
      workspaceLabels[String(workspace.workspace_id || "")] = label
      if (workspace.focused === true
          || String(workspace.workspace_id || "")
            === String(snapshot.focused_workspace_id || ""))
        focusedWorkspace = label
    }

    let working = 0
    let blocked = 0
    let done = 0
    for (let index = 0; index < agents.length; index++) {
      const status = String(agents[index].agent_status || "unknown")
      if (status === "working") working++
      else if (status === "blocked") blocked++
      else if (status === "done") done++
    }

    herdrStatus = ({
      available: true,
      loading: false,
      workspaces: workspaces.length,
      agents: agents.length,
      working: working,
      blocked: blocked,
      done: done,
      focusedWorkspace: focusedWorkspace,
      detail: agentStatusDetail(agents, workspaceLabels),
      summary: statusSummary(workspaces.length, agents.length)
    })
    return true
  }

  function markHerdrUnavailable() {
    herdrStatus = ({
      available: false,
      loading: false,
      workspaces: 0,
      agents: 0,
      working: 0,
      blocked: 0,
      done: 0,
      focusedWorkspace: "",
      detail: "Herdr-servern svarar inte",
      summary: ""
    })
  }

  function queryHerdrStatus() {
    if (herdrQuery.running) {
      herdrQueryPending = true
      return
    }
    herdrQuery.running = true
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
    if (!panelVisible || connectionReveal <= 0.001) {
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

  function beginClosing() {
    if (!panelVisible) return
    // Remove the caret before dispatching the close. The panel then owns the
    // entire exit animation instead of looking detached from a lingering bar.
    panelVisible = false
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
    if (name === "activespecial") {
      const parts = String(event.data || "").split(",")
      const workspace = String(parts[0] || "")
      const screen = String(parts[1] || "")
      if (workspace === "" && panelVisible
          && (activeScreenName === "" || screen === activeScreenName))
        beginClosing()
      queryClients()
      return
    }
    if (["openwindow", "closewindow", "movewindow", "movewindowv2",
         "monitoradded", "monitoraddedv2",
         "monitorremoved"].indexOf(name) >= 0) queryClients()
  }

  function toggle() {
    if (root.panelVisible) root.beginClosing()
    if (root.bar) root.bar.run("herdr-drop toggle")
    else Quickshell.execDetached(["herdr-drop", "toggle"])
  }

  function close() {
    if (!panelVisible) return
    root.beginClosing()
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
      hasBar: root.bar !== null,
      herdrStatus: herdrStatus
    })
  }

  onConnectionRevealChanged: publishConnection()
  onBarChanged: {
    syncTimer.restart()
    herdrStatusTimer.restart()
  }

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
    function beginClose(): void { root.beginClosing() }
    function refresh(): void { root.refreshState() }
    function refreshStatus(): void { root.queryHerdrStatus() }
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

  Timer {
    id: herdrStatusTimer
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.queryHerdrStatus()
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

  Process {
    id: herdrQuery
    command: ["herdr", "api", "snapshot"]
    stdout: StdioCollector { id: herdrOutput; waitForEnd: true }
    onExited: function(exitCode, _exitStatus) {
      let applied = false
      if (exitCode === 0) {
        try {
          applied = root.applyHerdrSnapshot(
            JSON.parse(herdrOutput.text || "{}"))
        } catch (_error) {}
      }
      if (!applied) root.markHerdrUnavailable()
      if (root.herdrQueryPending) {
        root.herdrQueryPending = false
        herdrStatusRetry.restart()
      }
    }
  }

  Timer {
    id: herdrStatusRetry
    interval: 50
    onTriggered: root.queryHerdrStatus()
  }
}
