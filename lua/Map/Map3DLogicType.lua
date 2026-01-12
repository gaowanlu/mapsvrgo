---@class OctreeType
---@field x number 左上前角x
---@field y number 左上前角y
---@field z number 左上前角z
---@field w number 宽度
---@field h number 高度
---@field d number 深度
---@field depth number 当前深度
---@field children table<integer,OctreeType> 子节点数组，初始为空 未分裂
---@field list table<integer,table> 存放直接属于此节点的对象

---@class Vec3i
---@field x integer
---@field y integer
---@field z integer

---@class Vec3f
---@field x number
---@field y number
---@field z number

---@class Map3DDbDataType
---@field id integer 地图ID
---@field TICK_RATE integer 帧率
---@field DT_MS integer 每帧时间间隔 毫秒
---@field lastTickTimeMS integer 执行上一次tick的毫秒时间戳
---@field durationAccumulator number 帧时常累计时间毫秒
---@field size Vec3i 地图大小

---@class Map3DPlayerType
---@field userId string 用户ID
---@field pos Vec3f 位置坐标
---@field v Vec3f 速度
---@field gravity integer 重力
---@field weight integer 重量
---@field lastSeq integer 最后收到并应用的客户端输入seq
---@field lastClientTime number 客户端发送该seq时的客户端时间(ms)
---@field dir Vec3f 方向
---@field speedRatio number 速度放大比例
---@field maxSpeed number 目标最大速度 px/ms
---@field accel number 加速度 px/ms^2
---@field friction number 每帧速度衰减系数
---@field bodyRadius number 角色碰撞半径
---@field octree OctreeType|nil 所在地图八叉树节点

---@class Map3DType
---@field MapDbData Map3DDbDataType
---@field players table<string,Map3DPlayerType>
---@field octree OctreeType 八叉树
