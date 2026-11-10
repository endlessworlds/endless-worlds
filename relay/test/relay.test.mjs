// Integration test against a running relay: `npm run dev` then `npm test`.
// RELAY=wss://your-worker.workers.dev npm test  checks a deployed one.
import assert from "node:assert/strict";

const RELAY = process.env.RELAY || "ws://127.0.0.1:8787";
const code = "T" + Math.random().toString(36).slice(2, 6).toUpperCase();

function connect(name, host) {
  const ws = new WebSocket(`${RELAY}/room/${code}?name=${name}&host=${host ? 1 : 0}`);
  const inbox = [];
  const waiters = [];
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    const w = waiters.findIndex((x) => x.pred(m));
    if (w >= 0) waiters.splice(w, 1)[0].resolve(m);
    else inbox.push(m);
  };
  ws.next = (pred, ms = 4000) => {
    const i = inbox.findIndex(pred);
    if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
    return new Promise((resolve, reject) => {
      waiters.push({ pred, resolve });
      setTimeout(() => reject(new Error(`${name}: timeout waiting`)), ms);
    });
  };
  return ws;
}
const is = (t) => (m) => m.t === t;

const ghost = connect("ghost", false);
assert.equal((await ghost.next(is("error"))).msg.startsWith("Room not found"), true);

const host = connect("host", true);
const hw = await host.next(is("welcome"));
assert.equal(hw.id, 1);

const a = connect("alice", false);
const aw = await a.next(is("welcome"));
assert.equal(aw.id, 2);
assert.deepEqual(aw.peers.map((p) => p.name), ["host"]);
assert.equal((await host.next(is("join"))).name, "alice");

// broadcast + sender stamping (client can't spoof "from")
a.send(JSON.stringify({ t: "pos", x: 5, from: 99 }));
const pos = await host.next(is("pos"));
assert.equal(pos.from, 2);
assert.equal(pos.x, 5);

// direct message only reaches its target
const b = connect("bob", false);
await b.next(is("welcome"));
host.send(JSON.stringify({ t: "riddle", to: 3, data: { riddle: "?" } }));
assert.equal((await b.next(is("riddle"))).from, 1);
await assert.rejects(a.next(is("riddle"), 600));

// 10-player cap
const extra = [];
for (let i = 0; i < 7; i++) {
  const p = connect("p" + i, false);
  await p.next(is("welcome"));
  extra.push(p);
}
const eleventh = connect("late", false);
assert.match((await eleventh.next(is("error"))).msg, /full/);

// leave + host_left
b.close();
assert.equal((await a.next((m) => m.t === "leave" && m.id === 3)).id, 3);
host.close();
await a.next(is("host_left"));

for (const p of [a, ...extra]) p.close();
console.log("relay: all tests passed");
process.exit(0);
