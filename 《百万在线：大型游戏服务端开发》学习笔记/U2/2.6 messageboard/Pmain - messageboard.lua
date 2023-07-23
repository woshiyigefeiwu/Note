local skynet = require "skynet"
local socket = require "skynet.socket"
local mysql = require "skynet.db.mysql"

local db= nil

function print_log_fjbq(oj,str)
    if (oj == nil) then 
        print(str .. " is nil ！！！")
    else
        print(str .. " is not nil")
    end
end

function connect(fd, addr)
    --启用连接
    print(fd.." connected addr:"..addr)
    socket.start(fd)

    print_log_fjbq(db,"db");

    --消息处理
    while true do
        local readdata = socket.read(fd)
		
		if readdata ~= nil then     --正常接收

            print(readdata)

			if readdata == "get\r\n" then       --返回留言板内容
				local res = db:query("select * from msgs")
				for i,v in pairs(res) do
					socket.write (fd, v.id.." "..v.text.."\r\n")
				end
			else            --留言
				local data = string.match( readdata, "set (.-)\r\n")
				db:query("insert into msgs (text) values (\'"..data.."\')")
			end
        else        --断开连接
            print(fd.." close ")
            socket.close(fd)
        end
	end
end

skynet.start(function()

    --网络监听
    local listenfd = socket.listen("0.0.0.0", 8888)
    socket.start(listenfd ,connect)

    -- 连接
    db=mysql.connect({
        host="127.0.0.1",
        port=3306,
        database="message_board",
        user="root",
        password="root",
        max_packet_size = 1024 * 1024,
        on_connect = nil
    })
    print_log_fjbq(db,"db");
end)
