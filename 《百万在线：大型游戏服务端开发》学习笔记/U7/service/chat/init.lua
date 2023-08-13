--[[
这里面定义的都是 chat 服务的回调函数（c++ 调用 lua）

--]]

local serviceId
local conns = {}

-- sunnet 底层在初始化chat服务的时候，c++会调用这里的lua代码
function OnInit(id)
    serviceId = id
    print("[lua] chat OnInit id:"..id)
    sunnet.Listen(8002, id)     -- lua 调用 c++，开启监听
end

-- sunnet 底层在接收到新的连接之后，c++会调用这里的lua代码
function OnAcceptMsg(listenfd, clientfd)
    print("[lua] chat OnAcceptMsg "..clientfd)
    conns[clientfd] = true
end

-- sunnet 底层在接收到数据的时候，c++会调用这里的lua代码
function OnSocketData(fd, buff)
    print("[lua] chat OnSocketData "..fd)
    for fd, _ in pairs(conns) do
        sunnet.Write(fd, buff)
    end
end

-- sunnet 底层要关闭服务的时候，c++会调用这里的lua代码
function OnSocketClose(fd)
    print("[lua] chat OnSocketClose "..fd)
    conns[fd] = nil
end