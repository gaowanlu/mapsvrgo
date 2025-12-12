-- PlayerLogic.lua logic script, reloadable

---@class RoleDbDataInfoType
---@field level number 玩家等级

---@class RoleDbDataBagType
---@field items table<number,number>

---@class PlayerComponentsType
---@field info PlayerCmptInfo
---@field bag PlayerCmptBag
---@field map PlayerCmptMap
---@field map3d PlayerCmptMap3D

---@class RoleDbDataType
---@field id string playerId
---@field clientGID number clientGID
---@field workerIdx number workerIdx
---@field userId string userID
---@field name string 用户名称
---@field x number
---@field y number
---@field Info RoleDbDataInfoType
---@field Bag RoleDbDataBagType

---@class PlayerType
---@field RoleDbData RoleDbDataType
---@field components PlayerComponentsType

---@class Player:PlayerType
local Player = require("PlayerData");

local Log = require("Log");
local PlayerCmptInfo = require("PlayerCmptInfoLogic")
local PlayerCmptBag = require("PlayerCmptBagLogic")
local PlayerCmptMap = require("PlayerCmptMapLogic")
local PlayerCmptMap3D = require("PlayerCmptMap3DLogic")
local ConfigTableMgr = require("ConfigTableMgrLogic")

---Player构造工厂
---@param playerId string
---@return Player
function Player.new(playerId)
    -- 创建一个Player对象 setmetatable({},{__index=Player})
    ---@type Player
    local self = setmetatable({}, Player)

    -- 模拟玩家的DB字段
    self.RoleDbData = {
        id = playerId,
        clientGID = 0,
        workerIdx = -1,
        userId = "",
        name = "Player_" .. tostring(playerId),
        x = 0,
        y = 0,
        Info = { level = 0 },
        Bag = { items = {} }
    };

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
    self.components = {
        info  = PlayerCmptInfo.new(self),
        bag   = PlayerCmptBag.new(self),
        map   = PlayerCmptMap.new(self),
        map3d = PlayerCmptMap3D.new(self)
    };

    return self
end

---@return RoleDbDataType
function Player:GetRoleDbData()
    return self.RoleDbData
end

---@return PlayerComponentsType
function Player:GetComponents()
    return self.components;
end

---@return string
function Player:GetPlayerID()
    return self:GetRoleDbData().id
end

---@return number
function Player:GetClientGID()
    return self:GetRoleDbData().clientGID
end

---@return number
function Player:GetWorkerIdx()
    return self:GetRoleDbData().workerIdx
end

---@return string
function Player:GetUserId()
    return self:GetRoleDbData().userId
end

---@param clientGID number
function Player:SetClientGID(clientGID)
    self:GetRoleDbData().clientGID = clientGID
end

---@param workerIdx number
function Player:SetWorkerIdx(workerIdx)
    self:GetRoleDbData().workerIdx = workerIdx
end

---@param userId string
function Player:SetUserId(userId)
    self:GetRoleDbData().userId = userId
end

function Player:OnTick()
    local userConfig = ConfigTableMgr.UserConfigs:get(self:GetUserId())
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
        comp:OnTick()
    end
end

function Player:OnLogin()
    for _, comp in pairs(self.components) do
        comp:OnLogin()
    end
end

function Player:OnLogout()
    for _, comp in pairs(self.components) do
        comp:OnLogout()
    end
end

return Player;
