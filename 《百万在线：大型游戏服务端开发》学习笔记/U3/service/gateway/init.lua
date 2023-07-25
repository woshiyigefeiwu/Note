
--[[
gateway 服务：
    负责对客户端消息的转发，收到客户端消息的时候；
    判断是发送给login服务，还是发送给agent服务；
    同时接收其他服务传过来的消息。
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
function player()
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


--------------------    -----------------------



--------------------    -----------------------





--------------------  -----------------------






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
    c.fd = c;

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

