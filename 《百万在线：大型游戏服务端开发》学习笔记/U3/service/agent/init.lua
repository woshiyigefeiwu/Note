--[[
agent 服务：玩家的代理

    处理玩家的数据消息，是一个核心服务；
    同时和 gateway 和 nodemgr 打交道
]]--

local skynet = require "skynet"
local s = require "service"

-- 和 login 一样封装一下
s.client = {}
s.gate = nil

require "scene"

-- 消息分发
s.resp.client = function (source, cmd, msg)
    s.gate = source;
   
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg,source)
        if ret_msg then     -- 发送给 gateway 或者 nodemgr（发送返回值）
            skynet.send(source, "lua", "send", s.id, ret_msg);
        end
    else
        skynet.error("s.resp.client fail", cmd)
    end
end

-- work 协议
s.client.work = function (msg)
    s.data.coin = s.data.coin + 1;
    return {"work", s.data.coin};
end

-- 接受客户端发过来的主动下线请求
s.client.kick = function (msg)  
    skynet.send(s.gate, "lua", "kick", s.id)
end

-- 这个是接收到agentmgr的消息
s.resp.kick = function (source)
	s.leave_scene()
	--在此处保存角色数据
	skynet.sleep(200)
end

s.resp.exit = function(source)
	skynet.exit()
end

-- 接收 scene 服务 发送给客户端的消息（scene -> agent -> gateway -> 客户端）
s.resp.send = function(source, msg)
	skynet.send(s.gate, "lua", "send", s.id, msg)
end

s.init = function()
	--playerid = s.id
	--在此处加载角色数据
	skynet.sleep(200)
	s.data = {
		coin = 100,
		hp = 200,
	}
end

s.start(...)



