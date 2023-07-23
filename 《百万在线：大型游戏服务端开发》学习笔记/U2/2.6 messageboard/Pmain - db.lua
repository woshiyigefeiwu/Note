local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

skynet.start(function()
    -- 连接
    local db=mysql.connect({
        host="127.0.0.1",
        port=3306,
        database="message_board",
        user="root",
        password="root",
        max_packet_size = 1024 * 1024,
        on_connect = nil
    })
    -- 插入
    local res = db:query("insert into msgs (text) values (\'hehe\')")
    -- 查询
    res = db:query("select * from msgs")
    -- 打印
    for i,v in pairs(res) do
        print ( i," ",v.id, " ",v.text)
    end
end)

--[[
我吐了，搞数据库搞了好久好久...
一开始想着能不能虚拟机连接主机的数据库，结果搞半天不太行...
然后就在虚拟机上装了数据库...
然后在主机上装 Navicat ，尝试连接虚拟机的数据库；
结果搞半天还是连接不了...

然后干脆就直接在虚拟机上装 Navicat...
然后运行代码发现没法插入...
发现是权限有问题，研究了一下...
好像是每个字段都得手动设置一下权限...

总算正常了....
]]--

