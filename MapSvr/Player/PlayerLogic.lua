-- PlayerLogic.lua logic script, reloadable
local Player = require("PlayerData");
local Log = require("Log");
local PlayerCmptInfo = require("PlayerCmptInfoLogic")
local PlayerCmptBag = require("PlayerCmptBagLogic")

-- Player类的方法
function Player.new(playerId)
    -- 创建一个Player对象 setmetatable({},{__index=Player})
    local self = setmetatable({}, Player)

    -- 模拟玩家的DB字段
    self.RoleDbData = {}
    self.RoleDbData.id = playerId
    self.RoleDbData.name = "Player_" .. tostring(playerId)
    self.RoleDbData.x = 0
    self.RoleDbData.y = 0

    -- PlayerCmptInfo 组件数据
    self.RoleDbData.Info = {
        level = 111
    }
    -- PlayerCmptBag 组件数据
    self.RoleDbData.Bag = {
        items = {}
    }
    self.RoleDbData.Bag.items[1001] = 1 -- 道具ID1001数量1个

    -- Player下组件挂载
    self.components = {}
    self:InitComponents()
    return self
end

function Player:GetRoleDbData()
    return self.RoleDbData
end

function Player:InitComponents()
    self.components.info = PlayerCmptInfo.new(self)
    self.components.bag = PlayerCmptBag.new(self)
end

function Player:GetComponent(name)
    return self.components[name]
end

function Player:GetPlayerID()
    return self:GetRoleDbData().id
end

function Player:OnTick()
    Log:Error("PlayerId %d", self:GetRoleDbData().id)
    self.RoleDbData.x = self.RoleDbData.x + 1
    self.RoleDbData.y = self.RoleDbData.y + 1
    if self.RoleDbData.x > 1000 then
        self.RoleDbData.x = 0
    end
    if self.RoleDbData.y > 1000 then
        self.RoleDbData.y = 0
    end

    -- 将Player的DB数据传给C++解析为Protobuf C++ 会将包传给MapSvr.OnLuaVMRecvMessage
    -- local res = avant.Lua2Protobuf(self.RoleDbData, 10);
    -- if res == nil then
    --     Log:Error("avant.Lua2Protobuf res nil ");
    -- else
    --     Log:Error("avant.Lua2Protobuf res " .. " " .. res);
    -- end

    -- Log:Error("=>PlayerOnTick playerId %d x %d y %d level %d", self.RoleDbData.id, self.RoleDbData.x, self.RoleDbData.y,
    --     self.RoleDbData.Info.level)

    for _, comp in pairs(self.components) do
        if comp.OnTick then
            comp:OnTick()
        end
    end
end

return Player;
