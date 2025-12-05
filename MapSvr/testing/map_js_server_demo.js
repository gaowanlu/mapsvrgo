// server.js
// ------------------------------------------------------------
// MMO / Action Server Demo - 完整服务器代码（修复 AOI 查询与去重）
// - 修复：qtQuery 现在只在 obj 在 range 内时才加入 out，且避免重复加入
// - 广播时只发送 AOI 内玩家（server 中 AOI 为以玩家为中心 1200x1200）
// - 在接收 client input 时记录 lastSeq 与 lastClientTime，广播回客户端以便 reconciliation
// - 保留 QuadTree 结构（用于 AOI 查询）
// - Tile 碰撞与玩家间碰撞均被禁用（保留实现以便将来恢复）
// ------------------------------------------------------------

const WebSocket = require("ws");
const PORT = 20029;
const HOST = "0.0.0.0";

const wss = new WebSocket.Server({ host: HOST, port: PORT });
console.log(`Server running on ws://${HOST}:${PORT}`);

const TICK_RATE = 20; // 20Hz
const DT = 1 / TICK_RATE;

// ------------------------- TileMap ----------------------------
// 数据全 0（无障碍），保留结构以便将来恢复
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

// 禁用 tile 碰撞（占位）
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
        this.friction = 0.90; // 每帧速度衰减系数
        this.bounce = 0.40;

        this.dirX = 0; // 输入方向（归一化）
        this.dirY = 0;
        this.maxSpeed = 200; // 目标最大速度 (px/s)
        this.accel = 1200;   // 加速度 px/s^2

        // 用于客户端 reconciliation 的元数据
        this.lastSeq = 0;        // 最后收到并应用的客户端输入 seq
        this.lastClientTime = 0; // 客户端发送该 seq 时的客户端时间（ms）
    }
}

const players = {};

// 所有玩家出生点相同（地图中心）
function findSpawnPoint() {
    const mapW = tilemap.width * tilemap.tileSize;
    const mapH = tilemap.height * tilemap.tileSize;
    return { x: mapW / 2, y: mapH / 2 };
}

// 玩家运动（不做 tile 碰撞检测）
function physicsMove(p) {
    // 目标速度
    const targetVx = p.dirX * p.maxSpeed;
    const targetVy = p.dirY * p.maxSpeed;

    // 将当前速度平滑朝目标速度变化（受到加速度限制）
    const dx = targetVx - p.vx;
    const dy = targetVy - p.vy;
    const maxDeltaV = p.accel * DT;

    if (Math.abs(dx) > maxDeltaV) p.vx += Math.sign(dx) * maxDeltaV; else p.vx = targetVx;
    if (Math.abs(dy) > maxDeltaV) p.vy += Math.sign(dy) * maxDeltaV; else p.vy = targetVy;

    // 直接按速度移动（不检测 tile 碰撞）
    p.x += p.vx * DT;
    p.y += p.vy * DT;

    // 摩擦（速度衰减）
    p.vx *= p.friction;
    p.vy *= p.friction;
}

// 保留 resolvePlayerCollision（未调用）
function resolvePlayerCollision(a, b) {
    let dx = b.x - a.x;
    let dy = b.y - a.y;
    let dist = Math.hypot(dx, dy);
    const minDist = a.radius + b.radius;

    if (dist >= minDist) return;

    if (dist === 0) {
        const jitter = 0.001;
        dx = jitter;
        dy = 0;
        dist = jitter;
    }

    const nx = dx / dist;
    const ny = dy / dist;
    const overlap = minDist - dist;

    const totalMass = a.mass + b.mass;
    const aMove = (b.mass / totalMass) * overlap;
    const bMove = (a.mass / totalMass) * overlap;

    a.x -= nx * aMove;
    a.y -= ny * aMove;
    b.x += nx * bMove;
    b.y += ny * bMove;

    const rvx = b.vx - a.vx;
    const rvy = b.vy - a.vy;
    const vn = rvx * nx + rvy * ny;

    if (vn > 0) return;

    const restitution = Math.min(a.bounce, b.bounce);
    const impulse = -(1 + restitution) * vn / (1 / a.mass + 1 / b.mass);

    const ix = impulse * nx;
    const iy = impulse * ny;

    a.vx -= ix / a.mass;
    a.vy -= iy / a.mass;
    b.vx += ix / b.mass;
    b.vy += iy / b.mass;
}

// ------------------------- QuadTree AOI ----------------------------
// 只用于 AOI 查询（保留）
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

// 修复后的 qtQuery：只在 obj 实际在 range 内才加入 out，且避免重复（使用 seen Set）
function qtQuery(qt, range, out, seen) {
    // 如果节点与查询范围没有相交，直接返回
    if (!intersect(qt, range)) return;

    // 检查当前节点的对象列表：只有那些在 range 内的才加入
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

    // 递归子节点
    if (qt.children) {
        for (const c of qt.children) {
            qtQuery(c, range, out, seen);
        }
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
    ws.playerId = id; // 绑定

    // 立即发送 init（包含服务器时间）
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
            // 验证并归一化输入
            const dx = Number(msg.dirX) || 0;
            const dy = Number(msg.dirY) || 0;
            const len = Math.hypot(dx, dy);
            p.dirX = len > 0 ? dx / len : 0;
            p.dirY = len > 0 ? dy / len : 0;

            // 记录 seq 与 clientTime，供客户端 reconciliation 使用
            if (typeof msg.seq === 'number') p.lastSeq = msg.seq;
            if (typeof msg.clientTime === 'number') p.lastClientTime = msg.clientTime;
        }

        if (msg.type === "ping") {
            // 回 pong（包含服务器时间），客户端会根据此测 RTT/offset
            try {
                ws.send(JSON.stringify({
                    type: "pong",
                    clientTime: msg.clientTime || 0,
                    serverTime: now()
                }));
            } catch (e) { /* ignore send errors */ }
        }
    });

    ws.on("close", () => {
        delete players[ws.playerId];
    });

    ws.on("error", (err) => {
        // 可记录日志，保持简洁
        // console.error("ws error", err);
    });
});

// ------------------------- Game Loop ----------------------------

// 使用固定步长 + 累积器，避免 setInterval 抖动累积误差
let lastTime = Date.now();
let accumulator = 0.0;

function step() {
    const current = Date.now();
    let frameTime = (current - lastTime) / 1000; // seconds
    if (frameTime > 0.25) frameTime = 0.25; // 防止卡顿时爆炸
    lastTime = current;

    accumulator += frameTime;

    while (accumulator >= DT) {
        // 一次固定步长的逻辑更新
        fixedUpdate();
        accumulator -= DT;
    }

    // 轻量调度（与 TICK_RATE 保持近似）
    setTimeout(step, 1000 / (TICK_RATE * 1.5));
}

function fixedUpdate() {
    const ids = Object.keys(players);

    // 构建 QuadTree（用于 AOI 查询）
    const qt = new QuadTree(0, 0, tilemap.width * tilemap.tileSize, tilemap.height * tilemap.tileSize);
    for (const id of ids) {
        qtInsert(qt, { id, x: players[id].x, y: players[id].y });
    }

    // 物理：移动（已禁用 tile 的碰撞）
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

    // 广播状态给每个客户端（AOI: 只发送周围玩家）
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

        // 构造 players 状态数组：包括 lastSeq 以便客户端 reconciliation
        const playersPayload = list.map(o => {
            const pl = players[o.id];
            return {
                id: o.id,
                x: pl.x,
                y: pl.y,
                vx: pl.vx,
                vy: pl.vy,
                lastSeq: pl.lastSeq || 0,          // 关键：服务器已处理到的客户端输入 seq
                lastClientTime: pl.lastClientTime || 0 // 可选：客户端发送该 seq 的时间（ms）
            };
        });

        const payload = {
            type: "state",
            serverTime: nowMs,
            players: playersPayload
        };

        try { ws.send(JSON.stringify(payload)); } catch (e) { /* ignore send errors */ }
    });
}

// 启动 loop
step();

// 导出用于测试（可选）
module.exports = { players, tilemap };
