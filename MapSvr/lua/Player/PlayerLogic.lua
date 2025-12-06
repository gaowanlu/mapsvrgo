-- PlayerLogic.lua logic script, reloadable
local Player = require("PlayerData");
local Log = require("Log");
local PlayerCmptInfo = require("PlayerCmptInfoLogic")
local PlayerCmptBag = require("PlayerCmptBagLogic")
local ConfigTableMgr = require("ConfigTableMgrLogic")

-- Player类的方法
function Player.new(playerId)
    -- 创建一个Player对象 setmetatable({},{__index=Player})
    local self = setmetatable({}, Player)

    -- 模拟玩家的DB字段
    self.RoleDbData = {}
    self.RoleDbData.id = playerId
    self.RoleDbData.clientGID = 0
    self.RoleDbData.workerIdx = -1
    self.RoleDbData.userId = ""
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

function Player:GetClientGID()
    return self:GetRoleDbData().clientGID
end

function Player:GetWorkerIdx()
    return self:GetRoleDbData().workerIdx
end

function Player:GetUserId()
    return self:GetRoleDbData().userId
end

function Player:SetClientGID(clientGID)
    self:GetRoleDbData().clientGID = clientGID
end

function Player:SetWorkerIdx(workerIdx)
    self:GetRoleDbData().workerIdx = workerIdx
end

function Player:SetUserId(userId)
    self:GetRoleDbData().userId = userId
end

function Player:OnTick()
    local userConfig = ConfigTableMgr.UserConfigs:get(self:GetPlayerID())
    if userConfig ~= nil then
        -- Log:Error("PlayerOnTick userConfig %s", userConfig.userName)
    end

    -- Log:Error("PlayerId %s", self:GetRoleDbData().id)
    self.RoleDbData.x = self.RoleDbData.x + 1
    self.RoleDbData.y = self.RoleDbData.y + 1
    if self.RoleDbData.x > 1000 then
        self.RoleDbData.x = 0
    end
    if self.RoleDbData.y > 1000 then
        self.RoleDbData.y = 0
    end

    -- Log:Error("=>PlayerOnTick playerId %s x %d y %d level %d", self.RoleDbData.id, self.RoleDbData.x, self.RoleDbData.y,
    --     self.RoleDbData.Info.level)

    for _, comp in pairs(self.components) do
        if comp.OnTick then
            comp:OnTick()
        end
    end
end

function Player:OnLogin()
    for _, comp in pairs(self.components) do
        if comp.OnLogin then
            comp:OnLogin()
        end
    end
end

function Player:OnLogout()
    for _, comp in pairs(self.components) do
        if comp.OnLogin then
            comp:OnLogout()
        end
    end
end

return Player;
