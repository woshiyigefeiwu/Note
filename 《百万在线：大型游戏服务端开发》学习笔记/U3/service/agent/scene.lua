--[[
这个文件是agent处理场景战斗模块的代码；
agent可能需要很多的系统，比如邮件，成就系统等等；
每个系统都都重新写一个文件，然后在init里面包含一下就行；
]]--

local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil --scene_node
s.sname = nil --scene_id

-- 随机一个场景
local function random_scene()

    -- 选择 node
    local nodes = {}
    for i, v in pairs(runconfig.scene) do
        table.insert(nodes, i)
        if runconfig.scene[mynode] then     -- 和当前从节点相同的场景节点插入两次，提高选中的概率
            table.insert(nodes, mynode)
        end
    end

    local idx = math.random( 1, #nodes)
    local scenenode = nodes[idx]

    -- 根据上面选中的节点，选择具体场景
    local scenelist = runconfig.scene[scenenode]
    local idx = math.random( 1, #scenelist)
    local sceneid = scenelist[idx]
    return scenenode, sceneid
end

-- 接收客户端（gateway转发）过来的进入游戏的消息
s.client.enter = function(msg)
    if s.sname then
        return {"enter",1,"已在场景"}
    end
    local snode, sid = random_scene()
    local sname = "scene"..sid      -- 再发给场景服务器去判断
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())
    if not isok then
        return {"enter",1,"进入失败"}
    end
    s.snode = snode
    s.sname = sname
    return nil
end

-- 改变方向（接收客户端（gateway转发）过来的改变位置的的消息）
s.client.shift  = function(msg)
    if not s.sname then
        return
    end
    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.snode, s.sname, "shift", s.id, x, y)
end

s.leave_scene = function()
    -- 不在场景
    if not s.sname then
        return
    end
    s.call(s.snode, s.sname, "leave", s.id)
    s.snode = nil
    s.sname = nil
end
