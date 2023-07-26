
--[[
gateway 服务：
    负责对客户端消息的转发，收到客户端消息的时候；
    判断是发送给login服务，还是发送给agent服务；
    同时接收其他服务传过来的消息。

这里需要明确一个点：
    服务 和 客户端 之间通信是通过协议的，比如在这里就是：login,xxx,xxx\r\n
    而 服务 和 服务 之间的消息是通过 table 的，比如：{login, xxx , xxx}
]]--

local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"             -- 导入封装好的模块
local runconfig = require "runconfig"   -- 项目的配置文件


-------------------- 3.6.1 连接类和玩家类 --------------------

conns    = {}   -- [socket_id] = conn，存放所有的连接信息
players  = {}   -- [playerid] = gateplayer，存放所有在线玩家的信息

-- 连接类
function conn()
    local m = {     -- fd 关联 玩家id
        fd = nil;
        playerid = nil;
    }
    return m;
end

-- 玩家类
function gateplayer()
    local m = {     -- 玩家id 关联 玩家代理agent，连接类conn
        playerid = nil;
        agent = nil;
        conn = nil;
    }
    return m;
end


-------------------- 3.6.4 编码和解码 -----------------------

-- 对消息进行编码
local str_pack = function (cmd, msg)
    -- 对消息表msg中的消息用 , 连接起来
    return table.concat(msg, ",").."\r\n";
end

-- 对消息进行解码
local str_unpack = function (msgstr)
    local msg = {}

    while true do
        local arg, rest = string.match(msgstr, "(.-),(.*)");
        if(arg) then
            msgstr = rest;
            table.insert(msg, arg);
        else
            table.insert(msg, msgstr);
            break;
        end
    end

    return msg[1], msg;
end


-------------------- 3.6.6 发送消息接口 -----------------------

-- 将消息从 login 转发给 客户端
s.resp.send_by_fd = function (source, fd, msg)
    if not conns[fd] then
        return;
    end
    local buff = str_pack(msg[1],msg);  -- 封装成协议（编码）
    skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat( msg, ",").."}")
    socket.write(fd,buff);
end

-- 将消息从 agent 转发给 客户端
s.resp.send = function (source, playerid, msg)
    local gplayer = players[playerid];
    if gplayer == nil then
        return;
    end

    local c = gplayer.conn;
    if c == nil then
        return;
    end

    s.resp.send_by_fd(nil, c.fd, msg);
end


-------------------- 3.6.7 确认登录接口 -----------------------

-- 完成登录流程之后，login 会通知 gateway，
-- 将 客户端 和 agent 关联起来
s.resp.sure_agent = function (source, fd, playerid, agent)
    local conn = conns[fd];
    if not conn then        -- 登陆过程中已经下线
        skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登陆即下线")
		return false
    end

    conn.playerid = playerid;

    local gplayer = gateplayer();
    gplayer.playerid = playerid;
    gplayer.agent = agent;
    gplayer.conn = conn;
    players[playerid] = gplayer;

    return true;
end

-------------------- 3.6.8 登出流程 -----------------------

--[[
登出有两种方式:
1. 客户端掉线：在协程中会调用 disconnect()
2. 被顶替下线：走 s.resp.kick()
]]--

-- 处理断开连接
local disconnect = function (fd)
    local c = conns[fd];
    if not c then
        return;
    end
    
    local playerid = c.playerid;

    if(not playerid) then   -- 还未完成登录
        return;
    else                    -- 已经在游戏中
        players[playerid] = nil;
        local reason = "断线";
        -- 向 agentmgr 发送下线请求，由 agentmgr 仲裁
        skynet.call("agentmgr", "lua", "reqkick", playerid, reason);
    end
end

-- 顶替下线
s.resp.kick = function (source, playerid)
    local gplayer = players[playerid];
    if not gplayer then
        return;
    end

    local c = gplayer.conn;
    players[playerid] = nil;

    if(not c) then
        return;
    end
    conns[c.fd] = nil;
    disconnect(c.fd);
    socket.close(c.fd);
end

-------------------- 3.6.5 消息分发 -----------------------

-- 对消息进行逻辑处理（分发给其他服务）
local process_msg = function (fd, msgstr)
    local cmd, msg = str_unpack(msgstr);    -- 解码
    skynet.error("recv "..fd.." ["..cmd.."] {"..table.concat( msg, ",").."}")

    local conn = conns[fd];
    local playerid = conn.playerid

    -- 尚未完成登录流程（发给login服务，进行登录验证）
    if not playerid then
        local node = skynet.getenv("node");
        local nodecfg = runconfig[node];
        local loginid = math.random(1,#nodecfg.login);      -- 随机出一个login服务
        local login = "login" .. loginid;                   -- 服务的名字
        skynet.send(login, "lua", "client", fd, cmd, msg);  -- 向login发送消息
    -- 已经完成登录流程了，直接发送给代理
    else
        local gplayer = players[playerid];
        local agent = gplayer.agent;
        skynet.send(agent, "lua", "client", cmd, msg);
    end
end


-------------------- 3.6.3 处理客户端协议-----------------------

local process_buff = function (fd, readbuff)
    while true do
        -- 字符串的模式匹配，匹配成功的部分放在msgstr，剩下的放在rest
        local msgstr, rest = string.match(readbuff, "(.-)\r\n(.*)");
        if msgstr then
            readbuff = rest;
            process_msg(fd, msgstr);    -- 对客户端发送的一条消息进行逻辑处理（消息分发）
        else
            return readbuff;
        end
    end
end


--------------------3.6.2 接收客户端连接-----------------------

--每一条连接接收数据处理（协程体）
--协议格式 cmd,arg1,arg2,...#
local recv_loop = function (fd)
    socket.start(fd);   -- 开启连接
    skynet.error("socket connected " ..fd);

    local readbuff = "";
    while true do       -- 一直循环
        local recvstr = socket.read(fd);
        if recvstr then     -- 连接正常
            readbuff = readbuff .. recvstr;         -- 将读到的数据拼接一下
            readbuff = process_buff(fd, readbuff);  -- 按照分隔符\r\n处理一下消息，返回剩下的部分
        else                -- 连接关闭
            skynet.error("socket close " ..fd)
            disconnect(fd);     -- 处理断开连接
            socket.close(fd);   -- 关闭连接
            return;
        end
    end
end

-- 有新连接时走这里
local connect = function (fd, addr)
    print("connect from " .. addr .. " " .. fd)
    
    local c = conn();   -- 创建新连接
    conns[fd] = c;      -- 初始化
    c.fd = fd;

    -- 对于一个连接，创建一个协程去接收数据
    skynet.fork(recv_loop, fd); 
end

-- 从 s.start() 过来的，配置规定了服务走这里
function s.init()
    local node = skynet.getenv("node");     -- 获取当前服务所在的节点
    local nodecfg = runconfig[node];        -- 获取节点的配置
    local port = nodecfg.gateway[s.id].port;-- 获取当前服务的端口

    local listenfd = socket.listen("0.0.0.0", port);    -- 获取监听fd
    skynet.error("Listen socket :", "0.0.0.0", port);
    socket.start(listenfd, connect);        -- 开启监听
end

-- 服务开始运行的时候走这里
s.start(...)

