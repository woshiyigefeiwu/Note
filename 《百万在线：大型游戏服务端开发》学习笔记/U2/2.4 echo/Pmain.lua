local skynet = require "skynet"
local socket = require "skynet.socket"

function connect (fd, addr) -- 对端的fd，对端的ip地址

    --启用连接
    print(fd.." connected addr:"..addr)
    socket.start(fd)
    
    --消息处理
    while true do
        local readdata = socket.read(fd);

        if readdata ~= nil then --正常接收
            print(fd.." recv "..readdata)
            socket.write(fd, readdata)
        else                    --断开连接
            print(fd.." close ")
            socket.close(fd)
        end
    end
end

skynet.start(function ()
    local listenfd = socket.listen("0.0.0.0", 8888);
    socket.start(listenfd,connect);
end)





