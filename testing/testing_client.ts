// testing_client.ts

import * as net from "net";
import * as dgram from "dgram";
import WebSocket from "ws";
import { ProtoPackage } from "./proto_res/proto_message_head";
import { ProtoCmd } from "./proto_res/proto_cmd";
import {
    ProtoCSReqExample,
    ProtoCSResExample,
    ProtoCSReqLogin,
    ProtoCSResLogin,
    ProtoCSMapNotifyStateData,
    ProtoCSMapNotifyInitData,
    ProtoCSReqMapPing,
    ProtoCSResMapPong,
    ProtoCSReqMapInput,
    ProtoCSMapEnterReq,
    ProtoCSMapEnterRes,
    ProtoCSMapLeaveReq,
    ProtoCSMapLeaveRes
} from "./proto_res/proto_example";
import {
    ProtoIPCStreamAuthHandshake,
} from "./proto_res/proto_ipc_stream";

// ==========================================
// =============== 配置常量 =================
// ==========================================
const IP = "www.mfavant.xyz";
const PORT = 20025;
const UDP_IP = "www.mfavant.xyz";
const UDP_PORT = 20027;
const RPCIP = "www.mfavant.xyz";
const RPCPORT = 20026;
const APPID = "0.0.0.369";

const IS_WEBSOCKET = true;

const IS_TCP = false;
const IS_UDP = false;
const IS_TESTRPC = false;

// ==========================================
// =============== 工具函数 =================
// ==========================================

/** 编码 ProtoPackage 为 Buffer */
function encodeProtoPackage(pkg: ProtoPackage): Buffer {
    const writer = ProtoPackage.encode(pkg);
    return Buffer.from(writer.finish());
}

/** 解码 Buffer 为 ProtoPackage */
function decodeProtoPackage(data: Uint8Array): ProtoPackage {
    return ProtoPackage.decode(data);
}

/** 创建带 8 字节长度头的 TCP 包 */
function createTCPPackageWithHeader(payload: Buffer): { headLen: Buffer; payload: Buffer } {
    const headLen = Buffer.alloc(8);
    const uint64Value = BigInt(payload.length);
    const high = Number(uint64Value >> BigInt(32));
    const low = Number(uint64Value & BigInt(0xffffffff));
    headLen.writeUInt32BE(high, 0);
    headLen.writeUInt32BE(low, 4);
    return { headLen, payload };
}

/** 从 Buffer 读取 8 字节长度头 */
function readLengthHeader(buffer: Buffer): number {
    const high = buffer.readUInt32BE(0);
    const low = buffer.readUInt32BE(4);
    return Number((BigInt(high) << BigInt(32)) | BigInt(low));
}

// ==========================================
// =========== 创建请求包函数 ===============
// ==========================================

/** 创建 ProtoCSReqExample 请求包 */
function createCSReqExamplePackage(): Buffer {
    const csReqExample: ProtoCSReqExample = {
        testContext: Buffer.from(Date.now().toString(), "utf8"),
    };

    const reqPackage: ProtoPackage = {
        cmd: ProtoCmd.PROTO_CMD_CS_REQ_EXAMPLE,
        protocol: ProtoCSReqExample.encode(csReqExample).finish(),
    };

    return encodeProtoPackage(reqPackage);
}

/** 创建 ProtoCSReqLogin 请求包 */
function createCSReqLoginPackage(): Buffer {
    const csReqLogin: ProtoCSReqLogin = {
        userId: "2",
        password: "bob456",
    };

    const reqPackage: ProtoPackage = {
        cmd: ProtoCmd.PROTO_CMD_CS_REQ_LOGIN,
        protocol: ProtoCSReqLogin.encode(csReqLogin).finish(),
    };

    return encodeProtoPackage(reqPackage);
}

function createCSReqMapPingPackage(): Buffer {
    const csReqMapPing: ProtoCSReqMapPing = {
        clientTime: Date.now().toString(),
    };

    const reqPackage: ProtoPackage = {
        cmd: ProtoCmd.PROTO_CMD_CS_REQ_MAP_PING,
        protocol: ProtoCSReqMapPing.encode(csReqMapPing).finish(),
    };

    return encodeProtoPackage(reqPackage);
}

function createCSReqMapInputPackage(dirX: number, dirY: number, seq: number, clientTime: string): Buffer {
    const csReqMapInput: ProtoCSReqMapInput = {
        dirX: dirX,
        dirY: dirY,
        seq: seq,
        clientTime: clientTime,
    };

    const reqPackage: ProtoPackage = {
        cmd: ProtoCmd.PROTO_CMD_CS_REQ_MAP_INPUT,
        protocol: ProtoCSReqMapInput.encode(csReqMapInput).finish(),
    };

    return encodeProtoPackage(reqPackage);
}

function createCSMapEnterReqPackage(mapId: number): Buffer {
    const csMapEnterReq: ProtoCSMapEnterReq = {
        mapId: mapId,
    };

    const reqPackage: ProtoPackage = {
        cmd: ProtoCmd.PROTO_CMD_CS_MAP_ENTER_REQ,
        protocol: ProtoCSMapEnterReq.encode(csMapEnterReq).finish(),
    };

    return encodeProtoPackage(reqPackage);
}

function createCSMapLeaveReqPackage(): Buffer {
    const csMapLeaveReq: ProtoCSMapLeaveReq = {
        nothing: 0
    };

    const reqPackage: ProtoPackage = {
        cmd: ProtoCmd.PROTO_CMD_CS_MAP_LEAVE_REQ,
        protocol: ProtoCSMapLeaveReq.encode(csMapLeaveReq).finish(),
    };

    return encodeProtoPackage(reqPackage);
}

// ==========================================
// ============= RPC 客户端 =================
// ==========================================

interface AvantRPCObj {
    client: net.Socket | null;
    recvBuffer: Buffer;
    appId: string | null;
    SendPackage(pkg: ProtoPackage): void;
}

function CreateAvantRPC(
    rpcIP: string,
    rpcPort: number,
    onRecvPackage?: (rpcObj: AvantRPCObj, pkg: ProtoPackage) => void
): AvantRPCObj {
    const rpcObj: AvantRPCObj = {
        client: null,
        recvBuffer: Buffer.alloc(0),
        appId: null,
        SendPackage(pkg: ProtoPackage) {
            if (!this.client) {
                console.error("RPCObj Client is null");
                return;
            }
            const payload = encodeProtoPackage(pkg);
            const { headLen } = createTCPPackageWithHeader(payload);
            this.client.write(headLen);
            this.client.write(payload);
        },
    };

    const tryConnect = () => {
        console.log(`tryConnect RPC ${rpcIP}:${rpcPort}`);
        const client = net.createConnection({ port: rpcPort, host: rpcIP }, () => {
            console.log("RPC Connected to server");

            // 发送握手
            const handshake: ProtoIPCStreamAuthHandshake = {
                appId: Buffer.from(APPID, "utf8"),
            };
            const handshakePkg: ProtoPackage = {
                cmd: ProtoCmd.PROTO_CMD_IPC_STREAM_AUTH_HANDSHAKE,
                protocol: ProtoIPCStreamAuthHandshake.encode(handshake).finish(),
            };
            rpcObj.SendPackage(handshakePkg);

            // 发送示例请求
            const exampleReq: ProtoCSReqExample = {
                testContext: Buffer.from(Date.now().toString(), "utf8"),
            };
            const examplePkg: ProtoPackage = {
                cmd: ProtoCmd.PROTO_CMD_CS_REQ_EXAMPLE,
                protocol: ProtoCSReqExample.encode(exampleReq).finish(),
            };
            rpcObj.SendPackage(examplePkg);
        });

        rpcObj.client = client;
        rpcObj.recvBuffer = Buffer.alloc(0);
        rpcObj.appId = null;

        client.on("data", (data) => {
            rpcObj.recvBuffer = Buffer.concat([rpcObj.recvBuffer, data]);

            while (true) {
                if (rpcObj.recvBuffer.length <= 8) return;

                const packageLen = readLengthHeader(rpcObj.recvBuffer);
                if (rpcObj.recvBuffer.length < 8 + packageLen) return;

                const packageData = rpcObj.recvBuffer.subarray(8, 8 + packageLen);
                rpcObj.recvBuffer = rpcObj.recvBuffer.subarray(8 + packageLen);

                try {
                    const recvPkg = decodeProtoPackage(packageData);

                    if (recvPkg.cmd === ProtoCmd.PROTO_CMD_IPC_STREAM_AUTH_HANDSHAKE) {
                        const handshake = ProtoIPCStreamAuthHandshake.decode(recvPkg.protocol);
                        const appIdString = handshake.appId?.toString() || "";
                        console.log("appIdString", appIdString);
                        rpcObj.appId = appIdString;
                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE) {
                        const resExample = ProtoCSResExample.decode(recvPkg.protocol);
                        const testContextStr = resExample.testContext?.toString() || "";
                        const sendTime = parseInt(testContextStr);
                        const rttMs = !isNaN(sendTime) ? Date.now() - sendTime : "N/A";
                        console.log(`[RPC] protoCSResExample from ${rpcObj.appId} testContext "${testContextStr}" RTT: ${rttMs}ms`);
                    }

                    if (onRecvPackage) {
                        onRecvPackage(rpcObj, recvPkg);
                    }
                } catch (err: any) {
                    console.log(err.message);
                }
            }
        });

        client.on("end", () => {
            console.log("RPC end");
            setTimeout(tryConnect, 1000);
        });

        client.on("error", (err) => {
            console.log(err.message);
            setTimeout(tryConnect, 1000);
        });
    };

    tryConnect();
    return rpcObj;
}
// ==========================================
// =============== TCP 客户端 ===============
// ==========================================

function startTCPClient() {
    let tcpQpsCounter = 0;
    let tcpRttSum = 0;
    let tcpRttCount = 0;
    let isLoggedIn = false; // 添加登录状态标记

    setInterval(() => {
        const avgRtt = tcpRttCount > 0 ? (tcpRttSum / tcpRttCount).toFixed(2) : "N/A";
        console.log(`TCP PROTO_CMD_CS_RES_EXAMPLE QPS = ${tcpQpsCounter}, Avg RTT = ${avgRtt}ms`);
        tcpQpsCounter = 0;
        tcpRttSum = 0;
        tcpRttCount = 0;
    }, 1000);

    const sendTCPPackage = (client: net.Socket, payload: Buffer) => {
        const { headLen } = createTCPPackageWithHeader(payload);
        client.write(headLen);
        client.write(payload);
    };

    const doConnect = () => {
        console.log(`doConnect TCP Client ${IP}:${PORT}`);
        const client = net.createConnection({ port: PORT, host: IP }, () => {
            console.log("TCP Connected to server");

            // 重置登录状态
            isLoggedIn = false;

            // 先发送登录消息
            const loginPackage = createCSReqLoginPackage();
            sendTCPPackage(client, loginPackage);
        });

        let clientRecvBuffer = Buffer.alloc(0);

        client.on("data", (data) => {
            clientRecvBuffer = Buffer.concat([clientRecvBuffer, data]);

            while (true) {
                // TCP 需要先读取 8 字节长度头
                if (clientRecvBuffer.length <= 8) return;

                const packageLen = readLengthHeader(clientRecvBuffer);
                if (clientRecvBuffer.length < 8 + packageLen) return;

                // 跳过 8 字节头部，提取实际数据
                const packageData = clientRecvBuffer.subarray(8, 8 + packageLen);
                clientRecvBuffer = clientRecvBuffer.subarray(8 + packageLen);

                try {
                    const recvPkg = decodeProtoPackage(packageData);

                    // 处理登录响应
                    if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_LOGIN) {
                        const resLogin = ProtoCSResLogin.decode(recvPkg.protocol);
                        console.log(`[TCP] PROTO_CMD_CS_RES_LOGIN ret ${resLogin.ret} sessionId ${resLogin.sessionId}`);

                        if (resLogin.ret === 0) {
                            isLoggedIn = true;
                            console.log("[TCP] Login successful!");
                        } else {
                            console.log(`[TCP] Login failed with ret: ${resLogin.ret}`);
                        }
                    }
                    // 处理示例响应
                    else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE) {
                        tcpQpsCounter++;

                        const resExample = ProtoCSResExample.decode(recvPkg.protocol);
                        const testContextStr = resExample.testContext?.toString() || "";
                        const sendTime = parseInt(testContextStr);
                        const rttMs = !isNaN(sendTime) ? Date.now() - sendTime : 0;
                        if (rttMs > 0) {
                            tcpRttSum += rttMs;
                            tcpRttCount++;
                        }

                        // 继续发送下一个请求
                        if (isLoggedIn) {
                            const nextPackage = createCSReqExamplePackage();
                            sendTCPPackage(client, nextPackage);
                        }
                    }
                    // 处理地图状态通知
                    else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_MAP_NOTIFY_STATE_DATA) {
                        const mapData = ProtoCSMapNotifyStateData.decode(recvPkg.protocol);
                        console.log(`[TCP] serverTime ${mapData.serverTime}`);

                        if (mapData.players && mapData.players.length > 0) {
                            const player = mapData.players[0];
                            console.log("[TCP] Player data:");
                            console.log("  userId:", player.userId);
                            console.log("  x:", player.x);
                            console.log("  y:", player.y);
                            console.log("  vX:", player.vX);
                            console.log("  vY:", player.vY);
                            console.log("  lastSeq:", player.lastSeq);
                            console.log("  lastClientTime:", player.lastClientTime);
                        }
                    }
                    // 未知命令
                    else {
                        console.log("[TCP] unknown cmd", recvPkg.cmd);
                    }
                } catch (err: any) {
                    console.log("[TCP] Decode error:", err.message);
                }
            }
        });

        client.on("end", () => {
            console.log("[TCP] client end");
            isLoggedIn = false;
            setTimeout(doConnect, 1000);
        });

        client.on("error", (err) => {
            console.log("[TCP] error:", err.message);
            isLoggedIn = false;
            setTimeout(doConnect, 1000);
        });
    };

    doConnect();
}

// ==========================================
// =========== WebSocket 客户端 =============
// ==========================================

function startWebSocketClient() {
    let wsQpsCounter = 0;
    let wsRttSum = 0;
    let wsRttCount = 0;
    let lastSeq = 0;

    setInterval(() => {
        const avgRtt = wsRttCount > 0 ? (wsRttSum / wsRttCount).toFixed(2) : "N/A";
        console.log(`WebSocket PROTO_CMD_CS_RES_EXAMPLE QPS = ${wsQpsCounter}, Avg RTT = ${avgRtt}ms`);
        wsQpsCounter = 0;
        wsRttSum = 0;
        wsRttCount = 0;
    }, 1000);


    let intervalPerSecond: NodeJS.Timeout | null = null;
    let intervalPerLogicFrame: NodeJS.Timeout | null = null;

    const doConnectWebSocket = () => {
        if (intervalPerSecond) {
            clearInterval(intervalPerSecond);
            intervalPerSecond = null;
        }
        if (intervalPerLogicFrame) {
            clearInterval(intervalPerLogicFrame);
            intervalPerLogicFrame = null;
        }

        const wsUrl = `ws://${IP}:${PORT}`;
        console.log(`doConnectWebSocket Client ${wsUrl}`);

        try {
            const ws = new WebSocket(wsUrl);

            ws.on("open", () => {
                console.log("WebSocket Connected to server");
                ws.send(createCSReqLoginPackage()); // 登录
                ws.send(createCSReqExamplePackage());
                // 进入地图2
                ws.send(createCSMapEnterReqPackage(2));
                // 5秒后离开地图
                setTimeout(() => {
                    // ws.send(createCSMapLeaveReqPackage());
                }, 5000);
                let inputStop = false;
                // 每秒ping以下地图
                intervalPerSecond = setInterval(() => {
                    // ws.send(createCSReqMapPingPackage());
                    if (!inputStop) {
                        ws.send(createCSReqMapInputPackage(4, 3, ++lastSeq, Date.now().toString()));
                    }
                }, 1000);
                setTimeout(() => {
                    inputStop = true;
                    ws.send(createCSReqMapInputPackage(0, 0, ++lastSeq, Date.now().toString()));
                }, 10000); // 10秒后停止移动
                // 每帧执行每秒20帧
                intervalPerLogicFrame = setInterval(() => {

                }, 1000 / 20);
            });

            ws.on("message", (data: Buffer) => {
                try {
                    const recvPkg = decodeProtoPackage(new Uint8Array(data));

                    if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_LOGIN) {
                        const resLogin = ProtoCSResLogin.decode(recvPkg.protocol);
                        console.log(`PROTO_CMD_CS_RES_LOGIN ret ${resLogin.ret} sessionId ${resLogin.sessionId}`);

                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE) {
                        // 处理示例响应

                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_MAP_NOTIFY_STATE_DATA) {
                        const mapData = ProtoCSMapNotifyStateData.decode(recvPkg.protocol);
                        console.log(`PROTO_CMD_CS_MAP_NOTIFY_STATE_DATA ${JSON.stringify(mapData)}`);

                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_MAP_NOTIFY_INIT_DATA) {
                        const initData = ProtoCSMapNotifyInitData.decode(recvPkg.protocol);
                        console.log(`PROTO_CMD_CS_MAP_NOTIFY_INIT_DATA ${JSON.stringify(initData)}`);

                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_MAP_PONG) {
                        const pongData = ProtoCSResMapPong.decode(recvPkg.protocol);
                        console.log(`PROTO_CMD_CS_RES_MAP_PONG ${JSON.stringify(pongData)}`);

                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_MAP_ENTER_RES) {
                        const enterRes = ProtoCSMapEnterRes.decode(recvPkg.protocol);
                        console.log(`PROTO_CMD_CS_MAP_ENTER_RES ${JSON.stringify(enterRes)}`);

                    } else if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_MAP_LEAVE_RES) {
                        const leaveRes = ProtoCSMapLeaveRes.decode(recvPkg.protocol);
                        console.log(`PROTO_CMD_CS_MAP_LEAVE_RES ${JSON.stringify(leaveRes)}`);

                    } else {
                        console.log("[WebSocket] unknown cmd", recvPkg.cmd);
                    }
                } catch (err: any) {
                    console.log("[WebSocket] Decode error:", err.message);
                }
            });

            ws.on("close", () => {
                console.log("WebSocket closed");
                // setTimeout(doConnectWebSocket, 1000);
            });
            ws.on("error", (err) => {
                console.log("[WebSocket] error:", err.message);
                // setTimeout(doConnectWebSocket, 1000);
            });
        } catch (err: any) {
            console.log("[WebSocket] Connection error:", err.message);
            // setTimeout(doConnectWebSocket, 1000);
        }
    };

    doConnectWebSocket();
}

// ==========================================
// ============== UDP 客户端 ================
// ==========================================

function startUDPClient() {
    let udpQpsCounter = 0;
    let udpRttSum = 0;
    let udpRttCount = 0;

    const doConnectUDP = () => {
        console.log(`Starting UDP Client to ${UDP_IP}:${UDP_PORT}`);

        const udpClient = dgram.createSocket("udp4");

        udpClient.on("error", (err) => {
            console.log(`[UDP] Server error:\n${err.stack}`);
            udpClient.close();
        });

        udpClient.on("message", (msg: Buffer, rinfo) => {
            try {
                const recvPkg = decodeProtoPackage(msg);

                if (recvPkg.cmd === ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE) {
                    udpQpsCounter++;

                    const resExample = ProtoCSResExample.decode(recvPkg.protocol);
                    const testContextStr = resExample.testContext?.toString() || "";
                    const sendTime = parseInt(testContextStr);
                    const rttMs = !isNaN(sendTime) ? Date.now() - sendTime : 0;
                    if (rttMs > 0) {
                        udpRttSum += rttMs;
                        udpRttCount++;
                    }

                    // 收到回包后继续发送
                    const needSendBytes = createCSReqExamplePackage();
                    udpClient.send(needSendBytes, UDP_PORT, UDP_IP);
                } else {
                    console.log("[UDP] unknown cmd", recvPkg.cmd);
                }
            } catch (err: any) {
                console.log("[UDP] Decode error:", err.message);
            }
        });

        setInterval(() => {
            const avgRtt = udpRttCount > 0 ? (udpRttSum / udpRttCount).toFixed(2) : "N/A";
            console.log(`UDP QPS = ${udpQpsCounter}, Avg RTT = ${avgRtt}ms`);

            if (udpQpsCounter === 0) {
                console.log("UDP Start sending...");
                for (let i = 0; i < 100; i++) {
                    const needSendBytes = createCSReqExamplePackage();
                    udpClient.send(needSendBytes, UDP_PORT, UDP_IP, (err) => {
                        if (err) console.log("[UDP] Send error", err);
                    });
                }
            }

            udpQpsCounter = 0;
            udpRttSum = 0;
            udpRttCount = 0;
        }, 1000);
    };

    doConnectUDP();
}

// ==========================================
// =============== 主程序入口 ===============
// ==========================================

function main() {
    console.log("=".repeat(50));
    console.log("Starting Client...");
    console.log(`IS_TCP: ${IS_TCP}`);
    console.log(`IS_WEBSOCKET: ${IS_WEBSOCKET}`);
    console.log(`IS_UDP: ${IS_UDP}`);
    console.log(`IS_TESTRPC: ${IS_TESTRPC}`);
    console.log("=".repeat(50));

    if (IS_TCP) {
        startTCPClient();
    }

    if (IS_WEBSOCKET) {
        startWebSocketClient();
    }

    if (IS_UDP) {
        startUDPClient();
    }

    if (IS_TESTRPC) {
        const rpcConn = CreateAvantRPC(RPCIP, RPCPORT, (rpcObj, pkg) => {
            console.log(`RPC OnRecvPackage CMD = ${pkg.cmd} FROM APPID=${rpcObj.appId}`);
        });
    }
}

// 启动程序
main();
