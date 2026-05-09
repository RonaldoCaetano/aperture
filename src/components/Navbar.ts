// Minimal navbar — just a logo and a connection dot.
// All right-panel buttons (Chat, War Room, Messages, BEADS, Spiders) were
// removed when the launcher became the only UI surface. The agent's tmux
// window is the one and only place to interact with them.
export function createNavbar(titleEl: HTMLElement) {
  titleEl.innerHTML = `
    <span class="navbar__logo">APERTURE</span>
    <span class="navbar__dot navbar__dot--connected"></span>
  `;

  return {
    setConnected(connected: boolean) {
      const dot = titleEl.querySelector(".navbar__dot")!;
      dot.className = `navbar__dot navbar__dot--${connected ? "connected" : "disconnected"}`;
    },
  };
}
