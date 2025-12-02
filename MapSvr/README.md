# MapSvr

## 如何构建

* copy_avant2mapsvr.sh
* copy_avant_bin.sh
* copy_mapsvr2avant.sh 


将 上面 avant项目路径改为自己的

执行 copy_mapsvr2avant.sh 将MapSvr项目 protocol 和 src/app 拷贝到 avant 项目里，去avant项目build出可执行文件，再用 copy_avant_bin.sh 将 可执行文件拷到MapSvr里。

## 配置文件

在config下的 main.ini 与 ipc.json。

任务类型 可选 stream与websocket。

## 如何加新协议

加过新协议需要去 lua_plugin.cpp 处理 写 新的Cmd对应Message的构造工厂

```cpp
void lua_plugin::init_message_factory()
{
    this->message_factory[ProtoCmd::PROTO_CMD_LUA_TEST] = []()
    { return std::make_shared<ProtoLuaTest>(); };
    this->message_factory[ProtoCmd::PROTO_CMD_CS_REQ_EXAMPLE] = []()
    { return std::make_shared<ProtoCSReqExample>(); };
    this->message_factory[ProtoCmd::PROTO_CMD_CS_RES_EXAMPLE] = []()
    { return std::make_shared<ProtoCSResExample>(); };
    this->message_factory[ProtoCmd::PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_NEW_CLIENT_CONNECTION] = []()
    {
        return std::make_shared<ProtoTunnelWorker2OtherEventNewClientConnection>();
    };
    this->message_factory[ProtoCmd::PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION] = []()
    {
        return std::make_shared<ProtoTunnelWorker2OtherEventCloseClientConnection>();
    };
    this->message_factory[ProtoCmd::PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION] = []()
    {
        return std::make_shared<ProtoTunnelOtherLuaVM2WorkerCloseClientConnection>();
    };
    // ... 在此加入自己的协议
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

将emmy_core.so拷到MapSvr下

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

构建avant时，将CMakeLists.txt 中target_link_libraries 链一下 emmy_core.so

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

启动avant程序other线程将会阻塞在Other_dbg.waitIDE()

### VSCode 连接到 Other_dbg

VSCode运行与调试，选择 EmmyLua New Debug，就可以看见 Other_dbg.breakHere() 被触发。
