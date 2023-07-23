--[[
理一下流程：

因为要两个节点，所以有两份配置文件；
两份配置文件就代表了这两个节点（当然里面需要指定节点的名字）

然后所有的节点，服务的启动都会走到 Pmain 里面来；
所以我们在Pmain里面就需要根据不同的节点来创建不同的节点服务；
]]--

local skynet = require "skynet"
local cluster = require "skynet.cluster"    -- cluster 集群模式
require "skynet.manager"

skynet.start(function()

    cluster.reload({    -- 加载节点配置
        node1 = "127.0.0.1:7001",
        node2 = "127.0.0.1:7002"
    })
    local mynode = skynet.getenv("node")    -- 读取从配置文件里面过来的是哪个节点

    if mynode == "node1" then
        cluster.open("node1")                       -- 启动节点 node1
        local ping1 = skynet.newservice("ping")     -- 创建服务 ping1
        local ping2 = skynet.newservice("ping")     -- 创建服务 ping2
        skynet.send(ping1, "lua", "start", "node2", "pong")     -- 发送 start 消息，注意这里要带上目标节点
        skynet.send(ping2, "lua", "start", "node2", "pong")
    elseif mynode == "node2" then                   
        cluster.open("node2")                       -- 启动节点 node2
        local ping3 = skynet.newservice("ping")     
        skynet.name("pong", ping3)                  -- 将服务 ping3 改名为 pong
    end
end)