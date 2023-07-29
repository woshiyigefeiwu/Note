--[[
场景服务：当玩家点击进入游戏的时候，会找一个场景进入;

和 agent 打交道

]]--

local skynet = require "skynet"
local s = require "service"

local balls = {}    -- [playerid] = ball 存放所有的球
local foods = {}    -- [id] = food 存放所有的食物
local food_maxid = 0    -- 食物的最大id
local food_count = 0    -- 食物的数量

-- 球类
function ball()
    local m = {
        playerid = nil,     -- 玩家id
        node = nil,         -- 玩家所在节点
        agent = nil,        -- 玩家的agent代理
        x = math.random( 0, 100),   -- 球的坐标
        y = math.random( 0, 100),
        size = 2,           -- 球的大小
        speedx = 0,         -- 球的速度
        speedy = 0,
    }
    return m;
end

-- 食物类
function food()
    local m = {
        id = nil,       -- 食物的id
        x = math.random( 0, 100),   -- 食物的坐标
        y = math.random( 0, 100),
    }
    return m
end

-- 球列表(发送给agent)
local function balllist_msg()
    local msg = {"balllist"}
    for i, v in pairs(balls) do
        table.insert( msg, v.playerid )
        table.insert( msg, v.x )
        table.insert( msg, v.y )
        table.insert( msg, v.size )
    end
    return msg
end

-- 食物列表(发送给agent)
local function foodlist_msg()
    local msg = {"foodlist"}
    for i, v in pairs(foods) do
        table.insert( msg, v.id )
        table.insert( msg, v.x )
        table.insert( msg, v.y )
    end
    return msg
end

-- 广播（广播消息给场景中所有的球）
function broadcast(msg)
    for i, v in pairs(balls) do
        -- 因为两个玩家可能不是在同一个节点里面的，所有用封装好的send来屏蔽节点的差异
        s.send(v.node, v.agent, "send", msg)
    end
end

-- 进入（接收处理 agent 发送过来的 enter 消息）
s.resp.enter = function(source, playerid, node, agent)
    if balls[playerid] then     -- 当前玩家已经在场景中
        return false
    end

    local b = ball()
    b.playerid = playerid
    b.node = node
    b.agent = agent

    -- 广播 （给场景中所有的球，当前这个球的信息）
    local entermsg = {"enter", playerid, b.x, b.y, b.size}
    broadcast(entermsg)

    -- 记录
    balls[playerid] = b

    -- 回应
    local ret_msg = {"enter",0,"进入成功"}
    s.send(b.node, b.agent, "send", ret_msg)

    -- 发战场信息
    s.send(b.node, b.agent, "send", balllist_msg())
    s.send(b.node, b.agent, "send", foodlist_msg())
    return true
end

-- 退出（接收处理 agent 发送过来的玩家的离开信息）
s.resp.leave = function(source, playerid)
    if not balls[playerid] then
        return false
    end
    balls[playerid] = nil

    local leavemsg = {"leave", playerid}
    broadcast(leavemsg) -- 广播一下
end

-- 改变速度（客户端 -> gateway -> agent -> shift，接收处理一下）
s.resp.shift = function(source, playerid, x, y)
    local b = balls[playerid]
	if not b then
        return false
    end
    b.speedx = x
    b.speedy = y
end

-- 食物更新的函数（食物生成）
function food_update()
    if food_count > 50 then             -- 控制食物的数量
        return
    end

    if math.random( 1,100) < 98 then    -- 控制一下食物生成的时间
        return
    end

    food_maxid = food_maxid + 1
    food_count = food_count + 1
    local f = food()
    f.id = food_maxid
    foods[f.id] = f

    local msg = {"addfood", f.id, f.x, f.y}
    broadcast(msg)
end

-- 移动逻辑
function move_update()
    for i, v in pairs(balls) do     -- 遍历所有的球，根据速度改变他们的位置
        v.x = v.x + v.speedx * 0.2
        v.y = v.y + v.speedy * 0.2
        if v.speedx ~= 0 or v.speedy ~= 0 then
            local msg = {"move", v.playerid, v.x, v.y}
            broadcast(msg)          -- 然后广播
        end
    end
end

-- 吞下食物时的更新
function eat_update()
    for pid, b in pairs(balls) do       -- 遍历所有的球
        for fid, f in pairs(foods) do   -- 遍历所有的食物
            if (b.x-f.x)^2 + (b.y-f.y)^2 < b.size^2 then    -- 判断食物是否被吃
                b.size = b.size + 1         -- 记得改变球的大小
                food_count = food_count - 1
                local msg = {"eat", b.playerid, fid, b.size}
                broadcast(msg)
                foods[fid] = nil --warm
            end
        end
    end
end

-- 主循环的update，frame 是当前的帧数
function update(frame)
    food_update()   -- 生成食物
    move_update()   -- 更新移动
    eat_update()    -- 吞食更新
    --碰撞略
    --分裂略
end

-- 启动服务
s.init = function()
    skynet.fork(function()      -- 创建一个协程，用于保持一定帧率的update
        --保持帧率执行
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local isok, err = pcall(update, frame)
            if not isok then
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime = frame*20 - (etime - stime)
            if waittime <= 0 then
                waittime = 2
            end
            skynet.sleep(waittime)
        end
    end)
end

s.start(...)

