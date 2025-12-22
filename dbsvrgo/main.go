package main

import (
	"dbsvrgo/client"
	"dbsvrgo/db"
	"dbsvrgo/proto_res"
	"dbsvrgo/worker"
	"log"
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
			client.Send(proto_res.ProtoCmd_PROTO_CMD_CS_REQ_EXAMPLE, msg)
			w.SetClient(client)
			return nil
		},

		func(client *client.Client, pkg *proto_res.ProtoPackage) error {
			log.Println("RPC 收到包 CMD =", pkg.Cmd)

			w.Push(pkg)

			log.Println("移交给Worker处理")

			return nil
		})

	if err != nil {
		log.Fatalln("创建RPC client.Client 失败：", err)
	}

	select {}
}
