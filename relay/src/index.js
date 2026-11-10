// Endless Worlds multiplayer relay — a Cloudflare Worker + one Durable Object per room.
// It never runs game logic: it assigns player ids, enforces the 10-player cap and
// forwards JSON between the players of a room. The host's game is the authority.
//
//   wss://<worker>/room/<CODE>?name=<player>&host=1|0

const MAX_PLAYERS = 10;
// Big enough for a 12 s voice clip (base64 WAV) sent to the host for speech-to-text.
const MAX_MSG_BYTES = 768 * 1024;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/room\/([A-Z0-9]{4,8})$/i);
    if (!match) {
      return new Response("Endless Worlds relay is running.", { status: 200 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected a WebSocket upgrade", { status: 426 });
    }
    const id = env.ROOMS.idFromName(match[1].toUpperCase());
    return env.ROOMS.get(id).fetch(request);
  },
};

export class Room {
  constructor(state) {
    this.state = state;
  }

  players() {
    return this.state.getWebSockets().map((ws) => ({ ws, ...ws.deserializeAttachment() }));
  }

  async fetch(request) {
    const url = new URL(request.url);
    const wantsHost = url.searchParams.get("host") === "1";
    const name = (url.searchParams.get("name") || "Player").slice(0, 16);
    const players = this.players();

    const [client, server] = Object.values(new WebSocketPair());
    this.state.acceptWebSocket(server);

    // Reject over the socket so the game can show the reason.
    const hasHost = players.some((p) => p.id === 1);
    let error = null;
    if (players.length >= MAX_PLAYERS) error = "Room is full (10 players max)";
    else if (wantsHost && hasHost) error = "That room code is taken — try again";
    else if (!wantsHost && !hasHost) error = "Room not found — check the code";
    if (error) {
      server.serializeAttachment({ id: 0, name, rejected: true });
      server.send(JSON.stringify({ t: "error", msg: error }));
      server.close(4000, error);
      return new Response(null, { status: 101, webSocket: client });
    }

    let id = 1;
    if (!wantsHost) {
      const used = new Set(players.map((p) => p.id));
      id = 2;
      while (used.has(id)) id++;
    }
    server.serializeAttachment({ id, name });
    server.send(JSON.stringify({
      t: "welcome",
      id,
      peers: players.filter((p) => !p.rejected).map((p) => ({ id: p.id, name: p.name })),
    }));
    this.broadcast({ t: "join", id, name }, server);
    return new Response(null, { status: 101, webSocket: client });
  }

  broadcast(obj, except, to = 0) {
    const text = JSON.stringify(obj);
    for (const p of this.players()) {
      if (p.ws === except || p.rejected || (to && p.id !== to)) continue;
      try { p.ws.send(text); } catch (_) { /* socket closing */ }
    }
  }

  async webSocketMessage(ws, raw) {
    const me = ws.deserializeAttachment();
    if (!me || me.rejected || typeof raw !== "string" || raw.length > MAX_MSG_BYTES) return;
    let data;
    try { data = JSON.parse(raw); } catch (_) { return; }
    if (typeof data !== "object" || data === null) return;
    data.from = me.id; // never trust a client-supplied sender
    const to = Number(data.to) || 0;
    delete data.to;
    this.broadcast(data, ws, to);
  }

  async webSocketClose(ws) {
    this.drop(ws);
  }

  async webSocketError(ws) {
    this.drop(ws);
  }

  drop(ws) {
    const me = ws.deserializeAttachment();
    try { ws.close(1000, "bye"); } catch (_) {}
    if (!me || me.rejected) return;
    if (me.id === 1) {
      this.broadcast({ t: "host_left" }, ws);
      for (const p of this.players()) {
        if (p.ws !== ws) try { p.ws.close(4001, "host left"); } catch (_) {}
      }
    } else {
      this.broadcast({ t: "leave", id: me.id }, ws);
    }
  }
}
