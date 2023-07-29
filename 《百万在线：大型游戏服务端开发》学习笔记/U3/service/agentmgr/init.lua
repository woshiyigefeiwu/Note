--[[
agentmgr 服务：管理所有的 agent，控制着登录流程；
]]--

local skynet = require "skynet"
local s = require "service"

-- 状态（枚举值）
STATUS = {
    LOGIN = 2;
    GAME = 3;
    LOGOUT = 4;
}

-- 玩家列表
local players = {}

-- 玩家类
function mgrplayer()
    local m = {
        playerid = nil;     -- 玩家id
        node = nil;         -- 玩家对于gateway，agent对应的节点
        agent = nil;        -- 玩家对应的agent服务的id
        status = nil;       -- 玩家对于的状态
        gate = nil          -- 玩家对应的gateway服务的id
    }
    return m;
end

-- 这个就是 login 服务发过来的请求登录消息
s.resp.reqlogin = function (source, playerid, node, gate)
    local mplayer = players[playerid];

    -- 登录过程禁止顶替
    if (mplayer and mplayer.status == STATUS.LOGOUT) then
        skynet.error("reqlogin fail, at status LOGOUT " ..playerid);
		return false;
    end
    if (mplayer and mplayer.status == STATUS.LOGIN) then
		skynet.error("reqlogin fail, at status LOGIN " ..playerid)
		return false
	end

    -- 玩家还在线上，顶替掉
    if mplayer then
        local pnode = mplayer.node;
        local pagent = mplayer.agent;
        local pgate = mplayer.gate;
        mplayer.status = STATUS.LOGOUT;
        
        -- 向其他服务发消息直接用封装好的就行，能抹平不同节点的差异
        s.call(pnode, pagent, "kick");
        s.send(pnode, pagent, "exit");
        s.send(pnode, pgate, "send", playerid, {"kick","顶替下线"})
		s.call(pnode, pgate, "kick", playerid)
    end

    -- 上线
    local player = mgrplayer();
    player.playerid = playerid;
	player.node = node
	player.gate = gate
    player.agent = nil    
    player.status = STATUS.LOGIN
	players[playerid] = player

    -- 向 nodemgr 请求一个 agent
    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
	player.agent = agent
	player.status = STATUS.GAME
	return true, agent
end

-- 下线请求
s.resp.reqkick = function(source, playerid, reason)
	local mplayer = players[playerid]
	if not mplayer then
		return false
	end
	
    -- 只有在游戏中，才可以下线
	if mplayer.status ~= STATUS.GAME then
		return false
	end

	local pnode = mplayer.node
	local pagent = mplayer.agent
	local pgate = mplayer.gate
	mplayer.status = STATUS.LOGOUT

    -- 先向 agent 发送 kick 消息（这里agent需要保存一些东西）
	s.call(pnode, pagent, "kick")
    -- 然后再向 agent 发送 exit 消息（退出agent服务，销毁）
	s.send(pnode, pagent, "exit")
	s.send(pnode, pgate, "kick", playerid)
	players[playerid] = nil

	return true
end

s.start(...)

