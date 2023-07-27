--[[
封装服务的使用方法；
使得在写服务的时候更加方便

这里其实很奇妙哦~

首先是外面启动的服务会走到这里的start；
然后会走到这里的init；
然后注意这个init里面做了什么事情？
它把"lua"类型的消息 dispatch 了;

也就是说后面发的"lua"消息中，会走这里的dispatch；
然后 dispatch 里面走了 local fun = M.resp[cmd]；
也就是走了 resp 里面的函数（这些函数在各自的服务init里面定义了，所以不为空）
所以也就是，服务之间发送消息的时候（例如："lua" "login"）
其实就会走 xxx.resp[cmd] （例如 xxx 为 login1，cmd 为 "login"）

相当于是封装了一下
]]--

local skynet = require "skynet"
local cluster = require "skynet.cluster"   -- 集群

------------------------------下面是定义属性-----------------------------------

local M = {

    -- 服务的 类型 和 id
    name = "",      -- 服务的类型，比如 gateway 服务
    id = 0,         -- 服务的id，比如 gateway1，则 id = 1 

    -- 服务的 回调函数
    init = nil,
    exit = nil,

    -- 服务的 分法方法（就是每个服务收到不同消息时候调用的函数）
    resp = {},
}

------------------------------下面是服务的消息分发-----------------------------------

-- 打印错误提示和堆栈
function traceback(err)
	skynet.error(tostring(err))
	skynet.error(debug.traceback())
end

-- 消息分发（address是消息发送方，cmd是消息名字）
local dispatch = function(session, address, cmd, ...)
	local fun = M.resp[cmd]     -- 消息处理方法
	if not fun then
		skynet.ret()
		return
	end
	
    -- xpcall：安全的调用xpcall，并将返回值打包到ret中
	local ret = table.pack(xpcall(fun, traceback, address, ...))
	local isok = ret[1]     -- 第一个返回值是xpcall是否调用成功
	
	if not isok then
		skynet.ret()
		return
	end

    -- 解出返回值并发送回去
	skynet.retpack(table.unpack(ret,2))
end

--[[
function exit_dispatch()
	if M.exit then
		M.exit()
	end
	skynet.ret()
	skynet.exit()
end
--]]

------------------------------下面是启动服务逻辑-----------------------------------

function init()
    skynet.dispatch("lua", dispatch)    -- 实现消息路由
    if M.init then
        M.init()        -- 调用具体服务里面的init（注意是啥时候初始化的？？？）
    end
end

-- 一个服务的启动
function M.start(name, id, ...)
    M.name = name;          -- 初始化 name 和 id
    M.id = tonumber(id);
    
    skynet.start(init)
end

------------------------------下面是辅助方法-----------------------------------

-- 封装call和send，抹平节点差异，减少代码量

function M.call(node, srv, ...)             -- node 是消息发送方（服务）的node
	local mynode = skynet.getenv("node")    -- 当前服务所在的node
	if node == mynode then      -- 同一个节点内，那么直接 skynet 去 call 就行
		return skynet.call(srv, "lua", ...)
	else                        -- 如果不是同一个几点，那么就需要用到集群
		return cluster.call(node, srv, ...)
	end
end

function M.send(node, srv, ...)     -- 这个也是一样的
	local mynode = skynet.getenv("node")
	if node == mynode then
		return skynet.send(srv, "lua", ...)
	else
		return cluster.send(node, srv, ...)
	end
end

return M;
