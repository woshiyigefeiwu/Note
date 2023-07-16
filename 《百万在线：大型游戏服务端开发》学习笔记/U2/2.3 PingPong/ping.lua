local skynet = require "skynet"

local CMD = {}

function CMD.start(source, target)
    skynet.send(target, "lua", "ping", 1)
end

function CMD.ping(source, count)
    local id = skynet.self()
    skynet.error("["..id.."] recv ping count="..count)
    skynet.sleep(100)
    skynet.send(source, "lua", "ping", count+1)
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
      local f = assert(CMD[cmd])
      f(source,...)
    end)
end)

--[[
--这一块好绕啊...下面总结一下这个逻辑...
--
--首先在 Pmain.lua 中创建了两个名字为 ping 的服务 ping1，ping2；
--而我们可以发现这个名为 ping 的服务就是我们这个文件的程序；
--也就是说创建了两个这个程序的对象（可以这么理解，类比协程对吧！！！）
--
--注意这个程序是可以处理多种消息的哦！具体在往下面看：
--
--然后就是在 Pmain.lua 那边会发一个类型为 lua ，名字为 start 的消息，发给了ping1（带了一个参数ping2）
--
--然后 ping1 收到这个消息之后发现是 lua 类型的消息，那么就会去执行 dispatch 里面的那个匿名函数；
--匿名函数 function(session, source, cmd, ...) 中的 source 对应 Ping 服务，cmd 对应 start 消息名字；
--
--然后重点来了，lua 的语法啊！CMD[cmd] 和 CMD.cmd 产生的效果是一样的...
--
--也就说，f(start , ...) ping1 就会去找 CMD[start] <=> CMD.satrt;
--（注意这里的 ... 是 ping2 哦！Pmain 里面传过来的）
--
--而我们上面定义了 CMD.start 所以就会去执行定义的函数：
--
--所以 ping1 执行 CMD.start 时就会向 target（也就是ping2）发送消息；
--
--ping2 接收到 lua 类型，ping 名字的消息，也是相同的操作去执行；
--因为我们定义了 CMD.ping 所以可以执行 名字为 ping 的消息对应的函数；
--
--所以 ping1 ping2 就可以相互发消息了！
--
--（搞清楚 类 和 对象 的关系！）
--
--]]
