export interface AgentDef {
  name: string;
  model: string;
  role: string;
  prompt_file: string;
  tmux_window_id: string | null;
  status: string; // "stopped" | "running" | "error"
  /** Notification badge — set by the backend when this agent calls
   *  `send_message(to: "operator", ...)`. Cleared when the operator clicks
   *  the agent's row in the launcher. There is no chat panel; the
   *  agent's actual message body lives in their tmux scrollback. */
  attention?: boolean;
}
