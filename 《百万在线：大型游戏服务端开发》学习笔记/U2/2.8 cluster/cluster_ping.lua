local skynet = require "skynet"
local cluster = require "skynet.cluster"
local mynode = skynet.getenv("node")

local CMD = {}

--[[
source_node 是接收到消息的 源节点；
source_srv 是源节点的源服务；
count 是参数

节点1 的 ping1，ping2 服务
节点2 的 pong 服务
都会走这
]]--
function CMD.ping(source, source_node, source_srv, count)
    local id = skynet.self()
    skynet.error("["..id.."] recv ping count="..count)
    skynet.sleep(100)
    cluster.send(source_node, source_srv, "ping", mynode, skynet.self(), count+1)
end

--[[
target_node 是目标节点，target 是目标节点的目标服务

节点1 的 ping1 ping2 就是走这里，向节点2的pong服务发消息
]]--
function CMD.start(source, target_node, target)
    cluster.send(target_node, target, "ping", mynode, skynet.self(), 1)
end

skynet.start(function()     -- 这样还是和前面一样的套路
    skynet.dispatch("lua", function(session, source, cmd, ...)
      local f = assert(CMD[cmd])
      f(source,...)
    end)
end)