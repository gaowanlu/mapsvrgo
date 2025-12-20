package main

import (
	"dbsvrgo/client"
	"dbsvrgo/proto_res"
	"log"

	"google.golang.org/protobuf/proto"
)

func main() {
	rpcAddr := "127.0.0.1:20024"
	appId := "0.0.0.999"

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
