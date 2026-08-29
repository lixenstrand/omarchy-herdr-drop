.pragma library

function loading() {
  return ({
    available: false,
    loading: true,
    workspaces: 0,
    agents: 0,
    working: 0,
    blocked: 0,
    done: 0,
    focusedWorkspace: "",
    agentRows: [],
    detail: "Läser Herdr-status…",
    summary: ""
  })
}

function unavailable() {
  return ({
    available: false,
    loading: false,
    workspaces: 0,
    agents: 0,
    working: 0,
    blocked: 0,
    done: 0,
    focusedWorkspace: "",
    agentRows: [],
    detail: "Herdr-servern svarar inte",
    summary: ""
  })
}

function cleanWorkspaceLabel(value) {
  return String(value || "").replace(/^\[\d+\]\s*/, "").trim()
}

function cleanTerminalTitle(value) {
  return String(value || "")
    .replace(/^[\s\u2800-\u28ff✳✢✣✤✥●◐◓◑◒✓✔]+/, "").trim()
}

function compact(value, maxLength) {
  const text = String(value || "")
  return text.length <= maxLength
    ? text : text.slice(0, Math.max(1, maxLength - 1)) + "…"
}

function statusRank(status) {
  if (status === "blocked") return 0
  if (status === "done") return 1
  if (status === "working") return 2
  if (status === "idle") return 3
  return 4
}

function statusLabel(status) {
  if (status === "blocked") return "Väntar på dig"
  if (status === "done") return "Klar"
  if (status === "working") return "Arbetar"
  if (status === "idle") return "Redo"
  return "Okänd status"
}

function agentRow(agent, workspaceLabels) {
  const session = agent && agent.agent_session ? agent.agent_session : null
  return ({
    status: String(agent && agent.agent_status || "unknown"),
    name: String(agent && agent.agent ? agent.agent
      : session && session.agent ? session.agent : "agent"),
    workspace: cleanWorkspaceLabel(
      workspaceLabels[String(agent && agent.workspace_id || "")] || ""),
    title: compact(cleanTerminalTitle(agent
      && (agent.terminal_title_stripped || agent.terminal_title)), 48),
    sequence: Number(agent && agent.state_change_seq || 0)
  })
}

function orderedAgentRows(agents, workspaceLabels) {
  const rows = []
  for (let index = 0; index < agents.length; index++)
    rows.push(agentRow(agents[index], workspaceLabels))
  rows.sort(function(left, right) {
    const rankDifference = statusRank(left.status) - statusRank(right.status)
    if (rankDifference !== 0) return rankDifference
    const sequenceDifference = right.sequence - left.sequence
    if (sequenceDifference !== 0) return sequenceDifference
    return left.name.localeCompare(right.name)
  })
  return rows
}

function statusSummary(workspaceCount, agentCount) {
  const workspaces = workspaceCount === 1
    ? "1 workspace" : workspaceCount + " workspaces"
  if (agentCount === 0) return workspaces
  const agents = agentCount === 1
    ? "1 upptäckt agent" : agentCount + " upptäckta agenter"
  return workspaces + " · " + agents
}

function fromPayload(payload) {
  const result = payload && payload.result ? payload.result : null
  const snapshot = result && result.snapshot ? result.snapshot : null
  if (!snapshot || typeof snapshot !== "object") return null

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

  const rows = orderedAgentRows(agents, workspaceLabels)
  return ({
    available: true,
    loading: false,
    workspaces: workspaces.length,
    agents: agents.length,
    working: working,
    blocked: blocked,
    done: done,
    focusedWorkspace: focusedWorkspace,
    agentRows: rows,
    detail: rows.length > 0 ? "" : "Inga upptäckta agenter",
    summary: statusSummary(workspaces.length, agents.length)
  })
}

function badgeKind(status) {
  if (!status || (status.loading !== true && status.available !== true))
    return "offline"
  if (Number(status.blocked || 0) > 0) return "blocked"
  if (Number(status.done || 0) > 0) return "done"
  return "none"
}

function isWorking(status) {
  return !!status && Number(status.working || 0) > 0
}

function agentDetail(row, privacyMode) {
  let detail = String(row && row.name || "agent")
  if (privacyMode) return detail
  const workspace = String(row && row.workspace || "")
  const title = String(row && row.title || "")
  if (workspace !== "") detail += " i " + workspace
  if (title !== "" && title.toLowerCase() !== detail.toLowerCase())
    detail += " — " + title
  return detail
}

function tooltipLines(status, opened, privacyMode) {
  const current = status || loading()
  const action = opened ? "Stäng Herdr Drop" : "Öppna Herdr Drop"
  const workspace = privacyMode
    ? "" : String(current.focusedWorkspace || "")
  const lines = [workspace !== ""
    ? action + " · " + workspace + " fokuserad" : action]
  const rows = Array.isArray(current.agentRows) ? current.agentRows : []
  if (rows.length > 0) {
    for (let index = 0; index < rows.length && index < 2; index++)
      lines.push(statusLabel(rows[index].status) + ": "
        + agentDetail(rows[index], privacyMode))
  } else {
    lines.push(String(current.detail || "Inga upptäckta agenter"))
  }
  const summary = String(current.summary || "")
  if (summary !== "") lines.push(summary)
  return lines
}

function tooltip(status, opened, privacyMode) {
  return tooltipLines(status, opened, privacyMode).join("\n")
}
