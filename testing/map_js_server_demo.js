// server.js
// ------------------------------------------------------------
// MMO / Action Server Demo - 完整服务器代码（修复 AOI + 边界控制 + 输入归一化）
// - 修复：qtQuery 正确去重、只返回范围内对象
// - 修复：玩家不能跑出地图边界
// - 强化：服务器对客户端 input 做可靠归一化，防止异常/作弊
// - 广播：只发送 AOI 内玩家（1200x1200 方块）
// - Tile 碰撞 / 玩家碰撞 已禁用（保留结构）
// ------------------------------------------------------------

const WebSocket = require("ws");
const PORT = 20029;
const HOST = "0.0.0.0";

const wss = new WebSocket.Server({ host: HOST, port: PORT });
console.log(`Server running on ws://${HOST}:${PORT}`);

const TICK_RATE = 20; // 20Hz
const DT = 1 / TICK_RATE;

// ------------------------- TileMap ----------------------------
const tilemap = {
    tileSize: 50,
    width: 400,
    height: 400,
    data: new Uint8Array(400 * 400)
};
for (let i = 0; i < tilemap.data.length; i++) tilemap.data[i] = 0;

function tileAt(tx, ty) {
    if (tx < 0 || ty < 0 || tx >= tilemap.width || ty >= tilemap.height) return 0;
    return tilemap.data[ty * tilemap.width + tx];
}

function isBlockedCircle(x, y, radius) {
    return false;
}

// ------------------------- Physics ----------------------------

class Body {
    constructor(x, y) {
        this.x = x; this.y = y;
        this.vx = 0; this.vy = 0;

        this.radius = 12;
        this.mass = 1;
        this.friction = 0.90;
        this.bounce = 0.40;

        this.dirX = 0;
        this.dirY = 0;
        this.maxSpeed = 200;
        this.accel = 1200;

        this.lastSeq = 0;
        this.lastClientTime = 0;
    }
}

const players = {};

function findSpawnPoint() {
    const mapW = tilemap.width * tilemap.tileSize;
    const mapH = tilemap.height * tilemap.tileSize;
    return { x: mapW / 2, y: mapH / 2 };
}

// ---------- 玩家运动：加入地图边界限制 ----------
function physicsMove(p) {
    const targetVx = p.dirX * p.maxSpeed;
    const targetVy = p.dirY * p.maxSpeed;

    const dx = targetVx - p.vx;
    const dy = targetVy - p.vy;
    const maxDeltaV = p.accel * DT;

    if (Math.abs(dx) > maxDeltaV) p.vx += Math.sign(dx) * maxDeltaV; else p.vx = targetVx;
    if (Math.abs(dy) > maxDeltaV) p.vy += Math.sign(dy) * maxDeltaV; else p.vy = targetVy;

    p.x += p.vx * DT;
    p.y += p.vy * DT;

    p.vx *= p.friction;
    p.vy *= p.friction;

    // -------------------------
    // 地图边界控制
    // -------------------------
    const mapW = tilemap.width * tilemap.tileSize;
    const mapH = tilemap.height * tilemap.tileSize;
    const r = p.radius;

    if (p.x < r) p.x = r;
    if (p.y < r) p.y = r;
    if (p.x > mapW - r) p.x = mapW - r;
    if (p.y > mapH - r) p.y = mapH - r;
}

// // 保留 resolvePlayerCollision（未调用）
// function resolvePlayerCollision(a, b) {
//     let dx = b.x - a.x;
//     let dy = b.y - a.y;
//     let dist = Math.hypot(dx, dy);
//     const minDist = a.radius + b.radius;

//     if (dist >= minDist) return;

//     if (dist === 0) {
//         const jitter = 0.001;
//         dx = jitter;
//         dy = 0;
//         dist = jitter;
//     }

//     const nx = dx / dist;
//     const ny = dy / dist;
//     const overlap = minDist - dist;

//     const totalMass = a.mass + b.mass;
//     const aMove = (b.mass / totalMass) * overlap;
//     const bMove = (a.mass / totalMass) * overlap;

//     a.x -= nx * aMove;
//     a.y -= ny * aMove;
//     b.x += nx * bMove;
//     b.y += ny * bMove;

//     const rvx = b.vx - a.vx;
//     const rvy = b.vy - a.vy;
//     const vn = rvx * nx + rvy * ny;

//     if (vn > 0) return;

//     const restitution = Math.min(a.bounce, b.bounce);
//     const impulse = -(1 + restitution) * vn / (1 / a.mass + 1 / b.mass);

//     const ix = impulse * nx;
//     const iy = impulse * ny;

//     a.vx -= ix / a.mass;
//     a.vy -= iy / a.mass;
//     b.vx += ix / b.mass;
//     b.vy += iy / b.mass;
// }

// ------------------------- QuadTree AOI ----------------------------
class QuadTree {
    constructor(x, y, w, h, depth = 0) {
        this.x = x; this.y = y;
        this.w = w; this.h = h;
        this.depth = depth;
        this.children = null;
        this.list = [];
    }
}

const MAX_DEPTH = 6;
const MAX_OBJECTS = 10;

function containsNode(c, obj) {
    return (
        obj.x >= c.x && obj.y >= c.y &&
        obj.x < c.x + c.w && obj.y < c.y + c.h
    );
}

function qtInsert(qt, obj) {
    if (qt.children) {
        for (const c of qt.children) {
            if (containsNode(c, obj)) {
                qtInsert(c, obj);
                return;
            }
        }
        qt.list.push(obj);
        return;
    }

    qt.list.push(obj);

    if (qt.list.length > MAX_OBJECTS && qt.depth < MAX_DEPTH) {
        subdivide(qt);
    }
}

function subdivide(qt) {
    const hw = qt.w / 2;
    const hh = qt.h / 2;
    qt.children = [
        new QuadTree(qt.x, qt.y, hw, hh, qt.depth + 1),
        new QuadTree(qt.x + hw, qt.y, hw, hh, qt.depth + 1),
        new QuadTree(qt.x, qt.y + hh, hw, hh, qt.depth + 1),
        new QuadTree(qt.x + hw, qt.y + hh, hw, hh, qt.depth + 1),
    ];

    const old = qt.list.slice();
    qt.list.length = 0;
    for (const obj of old) {
        let inserted = false;
        for (const c of qt.children) {
            if (containsNode(c, obj)) {
                qtInsert(c, obj);
                inserted = true;
                break;
            }
        }
        if (!inserted) qt.list.push(obj);
    }
}

// ---------- 修复后的 qtQuery（去重 + 范围内才加入） ----------
function qtQuery(qt, range, out, seen) {
    if (!intersect(qt, range)) return;

    for (const obj of qt.list) {
        if (
            obj.x >= range.x &&
            obj.x < range.x + range.w &&
            obj.y >= range.y &&
            obj.y < range.y + range.h
        ) {
            if (!seen.has(obj.id)) {
                seen.add(obj.id);
                out.push(obj);
            }
        }
    }

    if (qt.children) {
        for (const c of qt.children) qtQuery(c, range, out, seen);
    }
}

function intersect(a, b) {
    return !(
        b.x > a.x + a.w ||
        b.x + b.w < a.x ||
        b.y > a.y + a.h ||
        b.y + b.h < a.y
    );
}

// ------------------------- Networking ----------------------------

function now() { return Date.now(); }

wss.on("connection", ws => {
    const id = Math.random().toString(36).slice(2);
    const spawn = findSpawnPoint();
    const p = new Body(spawn.x, spawn.y);
    players[id] = p;
    ws.playerId = id;

    try {
        ws.send(JSON.stringify({
            type: "init",
            id,
            x: p.x,
            y: p.y,
            serverTime: now(),
        }));
    } catch (e) { }

    ws.on("message", data => {
        let msg;
        try { msg = JSON.parse(data.toString()); } catch (e) { return; }

        if (msg.type === "input") {
            let dx = Number(msg.dirX);
            let dy = Number(msg.dirY);

            if (!Number.isFinite(dx)) dx = 0;
            if (!Number.isFinite(dy)) dy = 0;

            const len = Math.hypot(dx, dy);

            if (len > 0.0001) {
                // 服务器强制归一化
                dx /= len;
                dy /= len;

                // 可选安全：禁止加速外挂（方向长度 > 1）
                // if (len > 1.0001) {
                //     dx /= len;
                //     dy /= len;
                // }
            } else {
                dx = 0; dy = 0;
            }

            p.dirX = dx;
            p.dirY = dy;

            if (typeof msg.seq === "number") p.lastSeq = msg.seq;
            if (typeof msg.clientTime === "number") p.lastClientTime = msg.clientTime;
        }

        if (msg.type === "ping") {
            try {
                ws.send(JSON.stringify({
                    type: "pong",
                    clientTime: msg.clientTime || 0,
                    serverTime: now()
                }));
            } catch (e) { }
        }
    });

    ws.on("close", () => delete players[ws.playerId]);
});

// ------------------------- Game Loop ----------------------------

let lastTime = Date.now();
let accumulator = 0.0;

function step() {
    const current = Date.now();
    let frameTime = (current - lastTime) / 1000;
    if (frameTime > 0.25) frameTime = 0.25;
    lastTime = current;

    accumulator += frameTime;

    while (accumulator >= DT) {
        fixedUpdate();
        accumulator -= DT;
    }

    setTimeout(step, 1000 / (TICK_RATE * 1.5));
}

function fixedUpdate() {
    const ids = Object.keys(players);

    const qt = new QuadTree(0, 0, tilemap.width * tilemap.tileSize, tilemap.height * tilemap.tileSize);
    for (const id of ids) {
        qtInsert(qt, { id, x: players[id].x, y: players[id].y });
    }

    for (const id of ids) physicsMove(players[id]);

    // 注意：已禁用玩家间碰撞处理（保留注释以便恢复）
    /*
    for (const id of ids) {
        const a = players[id];
        const range = { x: a.x - 64, y: a.y - 64, w: 128, h: 128 };
        const candidates = [];
        const seen = new Set();
        qtQuery(qt, range, candidates, seen);
        for (const c of candidates) {
            if (c.id === id) continue;
            const b = players[c.id];
            if (c.id <= id) continue;
            resolvePlayerCollision(a, b);
        }
    }
    */

    const nowMs = now();

    wss.clients.forEach(ws => {
        if (ws.readyState !== 1) return;
        const id = ws.playerId;
        if (!id || !players[id]) return;

        const p = players[id];
        const range = { x: p.x - 600, y: p.y - 600, w: 1200, h: 1200 };

        const list = [];
        const seen = new Set();
        qtQuery(qt, range, list, seen);

        const playersPayload = list.map(o => {
            const pl = players[o.id];
            return {
                id: o.id,
                x: pl.x,
                y: pl.y,
                vx: pl.vx,
                vy: pl.vy,
                lastSeq: pl.lastSeq || 0,
                lastClientTime: pl.lastClientTime || 0
            };
        });

        const payload = {
            type: "state",
            serverTime: nowMs,
            players: playersPayload
        };

        try { ws.send(JSON.stringify(payload)); } catch (e) { }
    });
}

step();

module.exports = { players, tilemap };
