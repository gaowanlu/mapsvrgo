# MapSvr

运行在 [@mfavant/avant](https://github.com/mfavant/avant) 的游戏服务器框架。支持无感不停服逻辑热更新、支持客户端通过 TCP、UDP、WebSocket 连接服务器。服务器进程之间支持通过 TCP 收发协议交互。协议描述同一使用 [@protocolbuffers/protobuf](https://github.com/protocolbuffers/protobuf)。

## 如何构建项目

请参考此项目下的 Dockerfile 镜像构建过程。

## 配置文件

在 config 下的 main.ini 与 ipc.json。

任务类型 可选 TCP Stream 与 WebSocket。

## 如何添加新协议

有两个很重要的概念，协议 + 异步，进程间的交互同一采用收发协议方式，收发协议是异步的。

proto 文件放在 protocol 目录下，加过新协议需要去 lua_plugin.cpp 处理, 写新的 Cmd 对应 Message 的构造工厂。这样在 avant 接收到已经注册的协议时会将 C++ Protobuf 消息转为 lua table 后传给 luaVM 处理。

同理 luaVM 内发送 lua table 给 C++ 会将其转为 C++ Protobuf 消息。

```cpp
// 将C++与Lua需要交互的协议加进来
void lua_plugin::init_message_factory()
{
    REGISTER_MSG(ProtoCmd::PROTO_CMD_LUA_TEST, ProtoLuaTest);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_REQ_EXAMPLE, ProtoCSReqExample);
    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_RES_EXAMPLE, ProtoCSResExample);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_NEW_CLIENT_CONNECTION, ProtoTunnelWorker2OtherEventNewClientConnection);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION, ProtoTunnelWorker2OtherEventCloseClientConnection);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION, ProtoTunnelOtherLuaVM2WorkerCloseClientConnection);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_REQ_LOGIN, ProtoCSReqLogin);
    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_RES_LOGIN, ProtoCSResLogin);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_MAP_NOTIFY_INIT_DATA, ProtoCSMapNotifyInitData);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_REQ_MAP_PING, ProtoCSReqMapPing);
    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_RES_MAP_PONG, ProtoCSResMapPong);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_REQ_MAP_INPUT, ProtoCSReqMapInput);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_MAP_NOTIFY_STATE_DATA, ProtoCSMapNotifyStateData);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_MAP_ENTER_REQ, ProtoCSMapEnterReq);
    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_MAP_ENTER_RES, ProtoCSMapEnterRes);

    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_MAP_LEAVE_REQ, ProtoCSMapLeaveReq);
    REGISTER_MSG(ProtoCmd::PROTO_CMD_CS_MAP_LEAVE_RES, ProtoCSMapLeaveRes);
}
```

我们非常需要 proto 文件定义的类型，能够自动生成 lua 的类型注释，以及支持枚举。generate_lua.js 可以帮我们做到，将 proto 文件夹下的所有 proto 文件 生成对应的 lua 文件到 `lua/ProtoLua/` 下。然后在程序中 require 生效, 如 `MsgHandloerLogic.lua`。通过EmmyLua插件，很轻松的可以做到类型字段提示，以及类型勘误。

```lua
local proto_cmd = require("proto_cmd");
local proto_database = require("proto_database");
local proto_example = require("proto_example");
local proto_ipc_stream = require("proto_ipc_stream");
local proto_lua = require("proto_lua");
local proto_message_head = require("proto_message_head");
local proto_tunnel = require("proto_tunnel");
```

## 协议处理

lua 中的协议处理在，MsgHandlerLogic.lua 中。

* `MsgHandler:HandlerMsgFromUDP` 处理接收的 UDP 协议包。
* `MsgHandler:HandlerMsgFromOther` 处理来自其他进程的协议包。
* `MsgHandler:HandlerMsgFromClient` 处理来自客户端的协议包。
* `MsgHandler:Send2UDP` 发送协议包 UDP 数据给目标 IP 与端口。
* `MsgHandler:Send2IPC` 发送协议包给目标其他进程。
* `MsgHandler:Send2Client` 发送协议包给目标客户端连接，客户端连接可能是 WebSocket 或 TCP 连接。

## 关于 dbsvrgo

基于 avant TCP 进程交互由 Golang 写的数据库操作，将所有的 DB 操作都写在 dbsvrgo 进程上，lua 游戏逻辑服务器通过收发协议与 dbsvrgo 交互达到异步操作数据库。

```bash
avant(MapSvrGo luaVM) <---- TCP Protobuf ----> dbsvrgo(MySQL)
  appId: 1.1.1.1                               appId: 1.1.2.1
```

## 如何正确地停服

请定制自己的 UDP 协议，停止进程前发送自己的UDP停服协议，处理一些必要逻辑 如将所有 Player 强制下线，保存所有 Player 的 DB 数据，禁止让新的玩家登入等。

## 如何热更 Logic

在不停止进程的情况下，像进程发送信号, `MapSvr.OnReload` 将会被触发。信号触发方式是 avant 框架直接规定的。

```bash
kill -10 PID
```

`MapSvr.OnReload` 内部会将我们指定的 Logic 文件重新进行 Load。

一旦 OnReload 出错，更新过脚本内容后存在错误，将会直接使得进程崩溃，这是非常危险的操作，非必要情况下我们不应该考虑使用它。例如导致进程直接崩溃可能将会影响 Lua 中的 DB 数据存档，造成数据丢失回档。

## 如何调试 Lua

VSCode + Emmylua（VSCode插件）。

### build emmy_core.so

https://github.com/EmmyLua/EmmyLuaDebugger

```bash
mkdir build
cd build
cmake .. -DEMMY_LUA_VERSION=54 -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

### CMakeLists.txt

将 emmy_core.so 拷到 MapSvr 下。

改一下 lua_plugin.cpp。

```cpp
// 声明到 lua_plugin.cpp中
extern "C" int luaopen_emmy_core(lua_State *L);

// 将emmy_core加到other_lua_state中
luaL_requiref(this->other_lua_state, "emmy_core", luaopen_emmy_core, 1);
lua_pop(this->other_lua_state, 1);

void lua_plugin::on_other_init(avant::workers::other *ptr_other_obj)
{
    this->ptr_other_obj = ptr_other_obj;
    {
        this->other_lua_state = luaL_newstate();
        luaL_openlibs(this->other_lua_state);
        // 加载 emmy_core 模块
        luaL_requiref(this->other_lua_state, "emmy_core", luaopen_emmy_core, 1);
        lua_pop(this->other_lua_state, 1);
        other_mount();
        std::string filename = this->lua_dir + "/Init.lua";
        int isok = luaL_dofile(this->other_lua_state, filename.data());
        lua_plugin::lua_plugin_lua_return_not_is_ok_print_error(isok, this->other_lua_state);
        ASSERT_LOG_EXIT(isok == LUA_OK);
    }
    // ...
}
```

构建 avant 时，将 CMakeLists.txt 中 target_link_libraries 链一下 emmy_core.so。

```txt
target_link_libraries(${PROJECT_NAME} ... /dev_dir/mc_like/minecraft_like/MapSvr/emmy_core.so ${EXTERNAL_LIB})
```

### lua 中使用 emmy_core

Other.lua

```lua
local Other = {};
local Log = require("Log");
local MapSvr = require("MapSvr")

Other_dbg = {}; -- 创建全局dbg对象

function Other:OnInit()
    Other_dbg = require("emmy_core")
    Other_dbg.tcpListen("127.0.0.1", 9966)
    Other_dbg.waitIDE() -- 阻塞等待IDE连接

    local log = "OnOtherInit";
    Log:Error(log);
    MapSvr.OnInit()
    Other:OnReload();
end

function Other:OnStop()
    local log = "OnOtherStop";
    Log:Error(log);
    MapSvr.OnStop()
end

function Other:OnTick()
    Other_dbg.breakHere() -- 打断点
    MapSvr.OnTick()
end
```

### launch.json

MapSvr/.vscode/launch.json

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "emmylua_new",
            "request": "launch",
            "name": "EmmyLua New Debug",
            "host": "127.0.0.1",
            "port": 9966,
            "ext": [
                ".lua",
                ".lua.txt",
                ".lua.bytes"
            ],
            "ideConnectDebugger": true
        }
    ]
}
```

### 启动 avant

启动 avant 程序 other 线程将会阻塞在 Other_dbg.waitIDE()。

### VSCode 连接到 Other_dbg

VSCode 运行与调试，选择 EmmyLua New Debug，就可以看见 Other_dbg.breakHere() 被触发。

## 循环依赖问题

如 

main.lua

```lua
print("main.lua");
local AFunc = require("./A");
AFunc();

```

A.lua

```lua
print("A.lua");
local BFunc = require("./B");

function AFunc() 
	print("A");
	BFunc();
end

return AFunc;
```

B.lua

```lua
print("B.lua");
local CFunc = require("./C");

function BFunc() 
	print("B");
	CFunc();
end

return BFunc;
```

C.lua

```lua
print("C.lua");
local AFunc = require("./A");

function CFunc() 
	print("C");
	AFunc();
end

return CFunc;
```

```bash
$ lua main.lua
A.lua B.lua C.lua A.lua B.lua C.lua A.lua B.lua C.lua A.lua B.lua C.lua A.lua B.lua lua: error loading module './C' from file './//C.lua': C stack overflow stack traceback: [C]: in ? [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' ... (skipping 370 levels) [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' main.lua:2: in main chunk [C]: in ? stack traceback: [C]: in ? [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' ... (skipping 370 levels) [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' main.lua:2: in main chunk [C]: in ?
```

上面的三个文件形成了完美的循环 require:

* A.lua require B.lua
* B.lua require C.lua
* C.lua require A.lua

Lua的特性是：`require()` 会先创建一个空的 moudle 表放进 `package.loaded`，然后执行模块文件，如果模块文件在执行过程中又 
require 自己依赖链上的模块，就会不断嵌套执行，最终爆掉 C 栈。

每个模块执行时都还没 return 完成，所以 `package.loaded` 里对应模块仍然是 `"loading..."` 的状态，当 `C.lua` 再次 `require("./A")` 时，
lua 发现 A 已经加载，但仍会尝试执行 `A.lua` 的 chunk ,于是无限循环。

在业务代码中，由于复杂的业务，模块之间相互 require ,你可能经常遇到这种问题，不要慌，看看日志，改一改就好了，就像这样。

C.lua

```lua
print("C.lua");

function CFunc() 
    local AFunc = require("./A");
    print("C");
	AFunc();
end

return CFunc;
```

Lua加载模块时，检查 `package.loaded[name]`，如果有值且不是 nil 则直接返回这个值。如果值是 true (表示正在加载中)，Lua 并不会直接返回 true，Lua 会继续执行 loader 返回的 chunk(也就是文件内容)。Lua 仅仅用 true 作为“正在加载”的标记，但不阻止再次执行模块文件。
