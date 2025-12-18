# MapSvr

## 如何构建

请参考 Dockerfile 镜像构建过程。

## 配置文件

在 config 下的 main.ini 与 ipc.json。

任务类型 可选 stream 与 websocket。

## 如何加新协议

加过新协议需要去 lua_plugin.cpp 处理, 写新的 Cmd 对应 Message 的构造工厂

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

## 调试 Lua

VSCode + Emmylua（VSCode插件）

### build emmy_core.so

https://github.com/EmmyLua/EmmyLuaDebugger

```bash
mkdir build
cd build
cmake .. -DEMMY_LUA_VERSION=54 -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

### CMakeLists.txt

将 emmy_core.so 拷到 MapSvr 下

改一下 lua_plugin.cpp

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

构建 avant 时，将 CMakeLists.txt 中 target_link_libraries 链一下 emmy_core.so

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

启动 avant 程序 other 线程将会阻塞在 Other_dbg.waitIDE()

### VSCode 连接到 Other_dbg

VSCode 运行与调试，选择 EmmyLua New Debug，就可以看见 Other_dbg.breakHere() 被触发。

## Lua 常见循环依赖问题

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
require 自己依赖链上的模块，就会不断嵌套执行，最终爆掉 C栈。

每个模块执行时都还没 return 完成，所以 `package.loaded` 里对应模块仍然是 `"loading..."` 的状态，当 `C.lua` 再次 `require("./A")` 时，
lua 发现 A 已经加载，但仍会尝试执行 `A.lua` 的 chunk ,于是无限循环。

在业务代码中，由于复杂的业务，模块之间相互require,你可能经常遇到这种问题，不要慌，看看日志，改一改就好了，就像这样。

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

Lua加载模块时，检查 `package.loaded[name]`，如果有值且不是 nil 则直接返回这个值。如果值是true (表示正在加载中)，Lua并不会直接
返回 true，Lua会继续执行 loader 返回的 chunk(也就是文件内容)。Lua仅仅用 true 作为“正在加载”的标记，但不阻止再次执行模块文件。
