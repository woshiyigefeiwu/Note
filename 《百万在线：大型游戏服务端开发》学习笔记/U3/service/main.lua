local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"

skynet.start(function()

	--初始化
	local mynode = skynet.getenv("node")    -- 获取当前的节点
	local nodecfg = runconfig[mynode]       -- 获取当前节点的配置

	--节点管理
	local nodemgr = skynet.newservice("nodemgr","nodemgr", 0)   -- 先开启 nodemgr 服务
	skynet.name("nodemgr", nodemgr)

	--集群
	cluster.reload(runconfig.cluster)   -- 加载集群
	cluster.open(mynode)

	--gate（根据节点的配置文件，开启所有的 gateway 服务）
	for i, v in pairs(nodecfg.gateway or {}) do
		local srv = skynet.newservice("gateway","gateway", i)
		skynet.name("gateway"..i, srv)
	end

	--login（根据节点的配置文件，开启所有的 login 服务）
	for i, v in pairs(nodecfg.login or {})  do
	local srv = skynet.newservice("login","login", i)
		skynet.name("login"..i, srv)
	end

	--agentmgr（开启的 agentmgr 服务）
	local anode = runconfig.agentmgr.node
	if mynode == anode then     -- 在同一个节点里面，直接开启就行
		local srv = skynet.newservice("agentmgr", "agentmgr", 0)
		skynet.name("agentmgr", srv)
	else                        -- 不在同一个节点，创建一个代理
		local proxy = cluster.proxy(anode, "agentmgr")
		skynet.name("agentmgr", proxy)
	end

	--scene (sid->sceneid)（根据节点的配置文件，开启所有的 scene 服务）
	for _, sid in pairs(runconfig.scene[mynode] or {}) do
		local srv = skynet.newservice("scene", "scene", sid)
		skynet.name("scene"..sid, srv)
	end

	--退出自身
    skynet.exit()
end)
