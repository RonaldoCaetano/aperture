import { invoke } from "@tauri-apps/api/core";
import type { AgentDef } from "../types";

// Frontend-exposed Tauri commands. The launcher only needs five things:
// bootstrap the tmux session, list/start/stop/configure agents, and clear
// an agent's attention badge once the operator has acknowledged it.
export const commands = {
  tmuxCreateSession: (sessionName: string) =>
    invoke<string>("tmux_create_session", { sessionName }),
  tmuxSelectWindow: (windowId: string) =>
    invoke<void>("tmux_select_window", { windowId }),
  startAgent: (name: string) => invoke<void>("start_agent", { name }),
  stopAgent: (name: string) => invoke<void>("stop_agent", { name }),
  listAgents: () => invoke<AgentDef[]>("list_agents"),
  updateAgentModel: (name: string, model: string) =>
    invoke<void>("update_agent_model", { name, model }),
  clearAttention: (name: string) =>
    invoke<void>("clear_attention", { name }),
};
