# Multiplayer relay (Cloudflare Worker): developer guide

A ~110-line Cloudflare Worker that lets up to **10 players** share a room. It does **no game
logic**: it hands out player ids, enforces the room cap, stamps the sender on every message and
forwards JSON. The host's copy of the game runs the world, riddle and rounds.
See `docs/Multiplayer-How-It-Works.pdf` for diagrams.

```
game ──wss──▶ Worker  /room/<CODE>?name=<n>&host=1|0
                 └──▶ Durable Object "Room <CODE>"   (one per room, hibernating WebSockets)
```

**Live instance:** `wss://endless-worlds-relay.srujanmpadmashali.workers.dev`
(already in the project's `.env` as `RELAY_URL`, and the default in `core/net.gd`).

---

## 1. Run it on your machine

```bash
cd relay
npm install            # installs wrangler locally (first time only)
npm run dev            # → ws://127.0.0.1:8787
npm test               # integration test against the local relay (run in a second terminal)
```

Point the game at it by setting `RELAY_URL=ws://127.0.0.1:8787` in `.env`.

## 2. Deploy it for free

You need a free Cloudflare account. No credit card is needed for the Workers Free plan.

```bash
cd relay
npx wrangler login     # opens the browser once; the token is saved for this PC
npm run deploy         # prints https://endless-worlds-relay.<your-subdomain>.workers.dev
RELAY=wss://endless-worlds-relay.<your-subdomain>.workers.dev npm test   # check the live one
```

Then in the project root `.env`:

```
RELAY_URL=wss://endless-worlds-relay.<your-subdomain>.workers.dev
```

and rebuild the game (`tools/package.ps1`). The `.env` is baked into every build, so players need
no setup.

> **Already logged in?** `npx wrangler whoami` shows the account. This PC is already logged in
> (the same login the `solulu` project uses), and that's how the live instance was deployed.
> Wrangler keeps that token in `%APPDATA%\xdg.config\.wrangler\config\default.toml`;
> nothing secret lives in this repo.

### Deploying from GitHub Actions instead (optional)

1. Cloudflare dashboard → *My Profile → API Tokens → Create Token* → template **Edit Cloudflare Workers**.
2. GitHub repo → *Settings → Secrets and variables → Actions* → add `CLOUDFLARE_API_TOKEN`
   (and `CLOUDFLARE_ACCOUNT_ID`, shown on the Workers overview page).
3. The `deploy-relay` job in `.github/workflows/godot-ci.yml` then deploys on every push to `main`.
   Without the secret, the job skips itself.

## 3. Why it's free (and stays free)

| Piece | Free-plan fact |
|---|---|
| Worker + Durable Object | Durable Objects run on the **Workers Free** plan with the SQLite storage backend (`new_sqlite_classes` in `wrangler.toml`). |
| Idle rooms | The WebSocket **Hibernation API** (`state.acceptWebSocket`) lets the object sleep between messages without dropping sockets. |
| Messages | Incoming WebSocket messages are billed at **20 : 1** against the request quota; outgoing messages are free. |
| Over quota | On the Free plan, requests past the daily limit **fail**. You are never charged. |

Traffic is small: each player sends at most 12 position updates per second while moving and about
1 per second while standing still. With 10 players all running non-stop, that's about 120 msgs/s,
≈ 6 billed requests/s. Check the current daily free quota on Cloudflare's
[Durable Objects limits page](https://developers.cloudflare.com/durable-objects/platform/limits/)
and [pricing page](https://developers.cloudflare.com/durable-objects/platform/pricing/).

## 4. Protocol

Every frame is one JSON object with a `t` (type). The relay adds `from` (the sender's id) and
delivers to everyone else in the room, or to one player when the message has `to: <id>`.

| `t` | Direction | Purpose |
|---|---|---|
| `welcome` | relay → joiner | `{id, peers:[{id,name}]}`; the host is always id 1 |
| `join` / `leave` | relay → room | someone arrived / dropped |
| `error` | relay → joiner | `Room not found`, `Room is full (10 players max)`, `That room code is taken` |
| `host_left` | relay → room | host disconnected; the room is closed |
| `start`, `riddle`, `hint`, `pos`, `chat`, `won`, `api`, `api_reply` | game ↔ game | forwarded untouched (see `core/net.gd`) |

Limits enforced by the relay: 10 sockets per room, 768 KB per message (enough for a 12 s voice clip
that a guest sends to the host's AI), and client-supplied `from` values are overwritten.

## 5. Files

| File | What |
|---|---|
| `src/index.js` | Worker router + `Room` Durable Object |
| `wrangler.toml` | name, Durable Object binding `ROOMS`, SQLite migration |
| `test/relay.test.mjs` | join, broadcast, sender stamping, direct messages, 10-cap, leave, host_left |

## 6. Troubleshooting

- **Game says "Can't reach the multiplayer relay"**: check `RELAY_URL` in `.env` starts with
  `wss://` (or `ws://127.0.0.1:8787` for local dev) and that `curl https://<worker>` returns
  `Endless Worlds relay is running.`
- **"Room not found"**: the host must create the room first; codes are case-insensitive.
- **Web build can't connect**: pages served over `https` must use a `wss://` relay.
- **Logs**: `npx wrangler tail` streams live logs from the deployed worker.
