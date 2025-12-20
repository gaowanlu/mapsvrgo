package main

import (
	"dbsvrgo/client"
	"dbsvrgo/db"
	"dbsvrgo/proto_res"
	"dbsvrgo/worker"
	"log"

	"google.golang.org/protobuf/encoding/prototext"
	"google.golang.org/protobuf/proto"
)

func main() {
	rpcAddr := "127.0.0.1:20026"
	appId := "1.1.2.1"

	if err := db.Init("root:root@tcp(127.0.0.1:3306)/dbname?charset=utf8mb4"); err != nil {
		log.Fatal(err)
	}

	w := worker.New(1024)
	w.Start()

	_, err := client.NewClient(rpcAddr,
		appId,
		func(client *client.Client) error {
			client.SendHandshake() //发送握手
			msg := &proto_res.ProtoCSReqExample{
				TestContext: []byte("进程间通信测试"),
			}
			return client.Send(proto_res.ProtoCmd_PROTO_CMD_CS_REQ_EXAMPLE, msg)
		},
		func(client *client.Client, pkg *proto_res.ProtoPackage) error {
			log.Println("RPC 收到包 CMD =", pkg.Cmd)

			switch pkg.Cmd {

			case proto_res.ProtoCmd_PROTO_CMD_IPC_STREAM_AUTH_HANDSHAKE:
				var msg proto_res.ProtoIPCStreamAuthHandshake
				if err := proto.Unmarshal(pkg.Protocol, &msg); err != nil {
					log.Println("解析失败:", err)
				} else {
					log.Println("RPC握手成功 AppId:", string(msg.AppId))
				}

			case proto_res.ProtoCmd_PROTO_CMD_CS_RES_EXAMPLE:
				var msg proto_res.ProtoCSResExample
				if err := proto.Unmarshal(pkg.Protocol, &msg); err != nil {
					log.Println("解析失败:", err)
				} else {
					log.Printf(
						"RPC发来消息 AppId %s: ProtoCmd_PROTO_CMD_CS_RES_EXAMPLE %s",
						client.GetAppId(),
						string(msg.TestContext),
					)
					// msg := &proto_res.ProtoCSReqExample{
					//      TestContext: []byte("进程间通信测试"),
					// }
					// client.Send(proto_res.ProtoCmd_PROTO_CMD_CS_REQ_EXAMPLE, msg)
				}

			case proto_res.ProtoCmd_PROTO_CMD_DBSVRGO_WRITE_DBUSERRECORD_REQ:
				var msg proto_res.DbUserRecord
				if err := proto.Unmarshal(pkg.Protocol, &msg); err != nil {
					log.Println("解析失败:", err)
				} else {
					log.Println(prototext.Format(&msg))
					w.Push(&msg)
				}

			default:
				log.Println("未知的指令 CMD =", pkg.Cmd)
			}

			return nil
		})

	if err != nil {
		log.Fatalln("创建RPC client.Client 失败：", err)
	}

	select {}
}

// package main

// import (
// 	"log"
// 	"time"

// 	"dbsvrgo/db"
// 	p "dbsvrgo/proto_res"
// 	"dbsvrgo/worker"
// )

// func main() {
// 	if err := db.Init("root:root@tcp(127.0.0.1:3306)/dbname?charset=utf8mb4"); err != nil {
// 		log.Fatal(err)
// 	}

// 	w := worker.New(1024)
// 	w.Start()

// 	// 插入
// 	w.Push(&p.DbUserRecord{
// 		Op:       p.DbOpType_OP_INSERT,
// 		Id:       1,
// 		UserId:   "1",
// 		Password: "1",
// 		BaseInfo: &p.DbPlayerBaseInfo{
// 			Level: 1,
// 		}})

// 	w.Push(&p.DbUserRecord{
// 		Op:       p.DbOpType_OP_REPLACE,
// 		Id:       1,
// 		UserId:   "1",
// 		Password: "1",
// 		BaseInfo: &p.DbPlayerBaseInfo{
// 			Level: 2,
// 		}})

// 	w.Push(&p.DbUserRecord{
// 		Op:       p.DbOpType_OP_UPDATE,
// 		Id:       1,
// 		UserId:   "1",
// 		Password: "2",
// 		BaseInfo: &p.DbPlayerBaseInfo{
// 			Level: 3,
// 		}})

// 	// 稍微等一会 worker处理一会把刚才的操作处理完
// 	time.Sleep(500 * time.Millisecond)

// 	// 原生 where 查询
// 	res, err := w.SelectRaw(
// 		&p.DbUserRecord{},
// 		"userId = 1",
// 	)
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	for _, m := range res {
// 		u := m.(*p.DbUserRecord)
// 		log.Printf("user: %+v\n", u)
// 	}
// }
