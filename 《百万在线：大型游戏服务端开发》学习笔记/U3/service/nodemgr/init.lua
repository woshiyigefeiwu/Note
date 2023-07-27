--[[
nodemgr：节点管理服务
每个节点都会开启一个，提供创建服务的远程调用接口
]]--

local skynet = require "skynet"
local s = require "service"

s.resp.newservice = function(source, name, ...)
	local srv = skynet.newservice(name, ...)
	return srv
end

s.start(...)
