# testing

JavaScript、TypeScript UDP、TCP、WebSocket 协议调试。

## QuickStart

```bash
npm install
```

生成用ts-proto生成proto文件的ts文件

```bash
npm run proto_gen
```

转译出JavaScript到dist

```bash
npm run build
```

去dist下运行,例如

```bash
root@ser745692301841:/MapSvr/testing/dist# ls
proto_res  testing_client.js
root@ser745692301841:/MapSvr/testing/dist# node testing_client.js
```

或者,直接生成proto文件的ts文件后，直接运行

```bash
root@ser745692301841/MapSvr/testing# npm run proto_gen
root@ser745692301841/MapSvr/testing# npm run dev
```
