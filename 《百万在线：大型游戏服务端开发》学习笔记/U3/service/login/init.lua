--[[
login 服务：
    处理客户端的登录消息，和 gateway, agentmgr 打交道;

    这里为啥要搞一个 s.client 呢？

    首先我们要知道，这个 s.resp.client = function (source, fd, cmd, msg)
    这个函数是其他服务发送给login服务的接口；
    cmd是客户端协议类型；
    
    客户端发送的协议不止一个；
    也就是说客户端发送的cmd有多种；
    那么我们最暴力的方法就是在 s.resp.client 里面对cmd进行判断，
    然后做不同的处理，但是这样子不优雅...
    所以就封装了一层消息；

    也就是其他服务向login发消息的时候；
    发“client”类型的，然后不同cmd类型的；
]]--

local skynet = require "skynet";
local s = require "service"

s.client = {}
s.resp.client = function (source, fd, cmd, msg)
    if s.client[cmd] then
        local ret_msg = s.client[cmd](fd,msg,source);
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg);
    else
        skynet.error("s.resp.client fail", cmd)
    end
end

s.client.login = function (fd, msg, source)
    local playerid = tonumber(msg[2]);
    local pw = tonumber(msg[3]);
    local gate = source;
    node = skynet.getenv("node");

    -- 1. 校验：校验用户名密码
    if pw ~= 123 then
        return {"login", 1, "密码错误"}
    end

    -- 2. 经过 agentmgr 同意
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate);
    if not isok then
        return {"login", 1, "请求mgr失败"};
    end

    -- 3. 回应gate，让gate注册
    local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent) 
    if not isok then
        return {"login", 1, "gate注册失败"}
    end

    -- 走到这里表示登录验证都成功了
    skynet.error("login succ "..playerid)
    return {"login", 0, "登陆成功"}
end

s.start(...)
