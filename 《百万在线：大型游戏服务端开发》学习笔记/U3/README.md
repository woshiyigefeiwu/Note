第三章：案例《球球大作战》

--------------------------------------------------

# 3.1 - 3.4 搭建项目架子

---

## 3.3 搭架子 

各个 文件夹 / 文件 的作用：

--[[

etc：存放服务配置的文件夹

    config.node1：节点1的启动配置文件
    
    config.node2：节点2的启动配置文件
    
    runconfig.lua：一份描述服务端的拓扑结构的配置文件（存放的其实就是服务的位置之类的信息）

这个 config.node1 配置文件里面规定了搜索 服务的启动文件 的路劲（luaservice 这一行）

同时规定了 程序需要加载的Lua模块 的路径（lua_path）

&emsp;

注意，每个节点都有一份配置文件，这说明什么？

说明节点之间是相对独立的，每个节点需要通过配置文件自己启动一遍。

runconfig.lua 这个是独一份的！所有节点共享一份！

]]--

&emsp;

luaclib：存放一些C模块（.so 文件）

&emsp;

lualib：存放 Lua 模块
    
    service.lua：封装服务端这边的一些方法，使得代码更加简洁易懂
    
    （其实就是封装服务模块的使用方法）

&emsp;

service：存放各个服务的Lua代码

&emsp;

skynet：skynet框架

&emsp;

start.sh：启动服务器的脚本

&emsp;

---

## 3.4 封装以用的API

怎么理解 lualib/service 这个文件？

书中有一句话：

    当 login1 向 agentmgr 发送名为 reqlogin 的消息时；
    
    经过 service 模块的处理，agentmgr 中的 s.resp.reqlogin 方法被调用。

&emsp;


因此可以这么理解：

    service 是一个类，每个服务中都用到它s（相当于是创建了一个对象）；
    
    每个对象都可以自己定义函数（用于接收其他服务发送过来的不同种类的消息）
    
    这里类里面做了一些处理，当 服务1 向 服务2 发送 xxx 消息的时候；
    
    服务2 中的 s.resp.xxx 方法就会被调用（如果 服务2 有定义这个方法的话）

&emsp;

那么这个 service 是怎么处理的呢？
    
    这里我们首先得理解一个函数 skynet.dispatch("lua", function() end)
    
    这个函数的意思是，当发送方服务调用send/call时（也就是向接收方服务发送消息"lua"）
    
    在接收方服务会调用 function() end 去处理这个消息（创建一个协程）
    
    这里注意，是 在接收方服务去调用！在接收方服务去调用！在接收方服务去调用！
    
    （指的是在接收方的环境中去调用）
    
    或者说，是发送方主动调用了接收方的对应的函数。

&emsp;

    那么看回来这个service，里面有一个 skynet.dispatch("lua", dispatch)
    
    也就说，当发送方服务发送lua消息的时候，接收方会调用dispatch；
    
    接着我们看看这个dispatch干啥了；
    
    local dispacth = fucntion(...)
    
        local fun = M.resp[cmd]
        
        ...
    end
    
    可以看到，在 dispacth 函数中，它调用了发送方服务的 M.resp[cmd]；
    
    而服务在引用service的时候：local s = require "service";
    
    也就是会去调用 s.resp.cmd 方法（在各自的服务中定义）


&emsp;

    所以说，当发送消息的时候，接收方响应的函数能被调用。

&emsp;

这样也就理解了这个 service 的作用和原理；

带着对 service 的理解，再往下面看，这样才不会乱！！！

&emsp;

除此之外，service 还封装了 send 和 call 用于抹平节点间的差异

&emsp;

3.4 最后的小例子走的流程是：

&emsp;

首先走到 service/main.lua，里面创建了一个gateway服务（注意并且传了参数：gateway，1）；

因为配置文件里面设置了服务启动路径；

所以服务启动的时候，skynet 会去找到 service/[服务]/init.lua 作为服务启动的文件；

&emsp;

然后就启动服务了，就来到了 service/gateway/init.lua 文件里面；

里面用到了我们封装的API；

从 s.start(...) 开始（这里的...参数就是newserver时候传进来的 gateway 和 1）；

那么就又走到了 lualib/service.lua 里面；

调用 M.start() 去初始化（name 和 id），然后调用skynet.start(init)去调用gateway1服务里面的init；

&emsp;

那么问题来了，为什么在service.lua 里面的 init 里面的 M.init 不是空可以被调用，在start也没有给他初始化呀？？？

通过输出 print(tostring(M/s)) 可以发现：

在 service.lua 中的 M，和 gateway/init.lua 中的 s 其实是一个 table！！！

所以在 service.lua 中判断 M.init()，其实就是在看服务 gateway/init.lua 里面是否有init()！！！

（可能这是 lua 的特性？反正是没见过...有点神奇啊！）

&emsp;

然后就走到了 gateway/init.lua，然后输出，没了！

&emsp;

main.lua -> gateway/init.lua -> lualib/service.lua -> gateway/init.lua

--------------------------------------------------

# 3.5 - 3.11 开发底层框架

艹，断断续续的...学到后面有点乱了...

&emsp;

首先这个 service/ 文件夹，存放的是各个服务的代码；

里面有一个 main.lua，它是主服务；

&emsp;

main.lua (主服务)：
    
    一个节点启动时第一个被加载的服务；
    
    用于启动其他各个服务。

&emsp;

gateway/init.lua：(gateway 服务)：
    
    1. 接收客户端连接（连接之后会创建一个协程去处理这个连接(收发客户端消息)）
    
    2. 收发的客户端消息模式双方规定的，比如 \r\n 分割，那么 gateway 和 客户端 传递的消息就都是 .....\r\n...\r\n.......\r\n 的形式；
    
    3. 所以 gateway 就需要去解析一下，按照 \r\n 将 ... 处理出来（process_buff）
    
    4. 处理出来之后只是字符串 str = "login,1,1"，而 服务 与 服务 之间传递的消息是 {}，
    
    所以要转换成 {login, 1, 1} 的新式，也就是解码；当然其他服务发送给gatway，gateway再发送给客户端时，就需要编码了。
    
    5. 解码之后，需要根据不同的情况发送给不同的服务处理（process_msg）
    
    6. 与此同时，其他服务也需要给客户端发消息，但是是通过gateway转发的，所以gateway要接收消息，所以gateway还得定义一些接收消息的方法，（s.resp.send_by_fd 和 s.resp.send ），注意是gateway接收到消息的时候自动调用的方法哦！和上面的 service 的理解结合起来！
    
    7. 确认登录的接口（s.resp.sure_agent）
    
    8. 登出流程（s.resp.kick）

&emsp;

login/init.lua：（login 服务）
   
    1. 接收 gateway 的消息（s.resp.client 和 s.client.login），并处理登录信息

&emsp;

agentmgr/init.lua：（agentmgr 服务）
    
    1. 管理所有的 agent 
    
    2. 接收 login 服务发送过来的请求登录的消息（s.resp.reqlogin）
    
    3. 接收 login 服务发送过来的请求登出的消息（s.resp.reqkick）

&emsp;

nodemgr/init.lua：（nodemgr 服务）
   
    1. 接收 agentmgr 服务的消息，创建一个新的 agent 服务（s.resp.newservice）

&emsp;

agent/init.lua：（agent 服务）
   
    1. 登录成功后，会接收 gateway 服务转发的来自客户端的消息）(s.resp.client)
   
    2. 接收 agentmgr 服务发送的 kick 和 exit 消息（s.resp.kick 和 s.resp.exit）


--------------------------------------------------

# 3.12 - 3.15 编写游戏逻辑

终于搞完了...

---





















