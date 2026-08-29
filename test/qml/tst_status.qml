import QtQuick
import QtTest
import "../../integrations/shibumi/plugin/Status.js" as Status

TestCase {
  name: "HerdrStatus"

  function workspace(id, label, focused) {
    return ({ workspace_id: id, label: label, focused: focused === true })
  }

  function agent(state, name, title, workspaceId, sequence) {
    return ({
      agent: name,
      agent_status: state,
      terminal_title_stripped: title,
      workspace_id: workspaceId,
      state_change_seq: sequence || 0
    })
  }

  function payload(workspaces, agents, focusedId) {
    return ({ result: { snapshot: {
      workspaces: workspaces,
      agents: agents,
      focused_workspace_id: focusedId || ""
    } } })
  }

  function basicPayload(state) {
    return payload(
      [workspace("w1", "[1] core", true)],
      [agent(state, "codex", "Implementera status", "w1", 10)],
      "w1")
  }

  function test_idle() {
    const status = Status.fromPayload(basicPayload("idle"))
    compare(Status.badgeKind(status), "none")
    verify(!Status.isWorking(status))
    verify(Status.tooltip(status, false, false)
      .indexOf("Redo: codex i core — Implementera status") >= 0)
  }

  function test_working() {
    const status = Status.fromPayload(basicPayload("working"))
    compare(Status.badgeKind(status), "none")
    verify(Status.isWorking(status))
    verify(Status.tooltip(status, true, false)
      .indexOf("Arbetar: codex i core — Implementera status") >= 0)
  }

  function test_done() {
    const status = Status.fromPayload(basicPayload("done"))
    compare(Status.badgeKind(status), "done")
    verify(Status.tooltip(status, false, false).indexOf("Klar: codex") >= 0)
  }

  function test_blocked() {
    const status = Status.fromPayload(basicPayload("blocked"))
    compare(Status.badgeKind(status), "blocked")
    verify(Status.tooltip(status, false, false)
      .indexOf("Väntar på dig: codex") >= 0)
  }

  function test_no_agents() {
    const status = Status.fromPayload(payload([
      workspace("w1", "[1] core", true),
      workspace("w2", "[2] docs", false)
    ], [], "w1"))
    const tooltip = Status.tooltip(status, false, false)
    compare(status.agents, 0)
    compare(status.summary, "2 workspaces")
    verify(tooltip.indexOf("Inga upptäckta agenter") >= 0)
  }

  function test_offline() {
    const status = Status.unavailable()
    compare(Status.badgeKind(status), "offline")
    verify(Status.tooltip(status, false, false)
      .indexOf("Herdr-servern svarar inte") >= 0)
  }

  function test_two_highest_priority_agents_are_shown() {
    const status = Status.fromPayload(payload(
      [workspace("w1", "[1] core", true)],
      [
        agent("working", "claude", "Bygger", "w1", 30),
        agent("done", "codex", "Klar uppgift", "w1", 20),
        agent("blocked", "gemini", "Behöver svar", "w1", 10)
      ], "w1"))
    const lines = Status.tooltipLines(status, false, false)
    verify(lines[1].indexOf("Väntar på dig: gemini") === 0)
    verify(lines[2].indexOf("Klar: codex") === 0)
    verify(lines.join("\n").indexOf("Arbetar: claude") < 0)
    compare(status.summary, "1 workspace · 3 upptäckta agenter")
  }

  function test_privacy_mode_hides_workspace_and_terminal_title() {
    const status = Status.fromPayload(payload(
      [workspace("w1", "[1] hemlig-kund", true)],
      [agent("working", "codex", "hemlig terminaluppgift", "w1", 10)],
      "w1"))
    const tooltip = Status.tooltip(status, false, true)
    verify(tooltip.indexOf("Arbetar: codex") >= 0)
    verify(tooltip.indexOf("hemlig-kund") < 0)
    verify(tooltip.indexOf("hemlig terminaluppgift") < 0)
  }

  function test_long_unicode_title_is_preserved_and_bounded() {
    const longTitle = "🚀 修正する väldigt lång uppgift " + "x".repeat(80)
    const status = Status.fromPayload(payload(
      [workspace("w1", "[1] core", true)],
      [agent("working", "codex", longTitle, "w1", 10)], "w1"))
    verify(status.agentRows[0].title.indexOf("🚀 修正する") === 0)
    compare(status.agentRows[0].title.length, 48)
    verify(status.agentRows[0].title.endsWith("…"))
  }
}
