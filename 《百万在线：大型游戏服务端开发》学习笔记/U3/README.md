第三章：案例《球球大作战》

--------------------------------------------------

# 3.1 - 3.4 搭建项目架子

---

## 3.3 搭架子 

各个 文件夹 / 文件 的作用：

etc：存放服务配置的文件夹
    config.node1：节点1的启动配置文件
    config.node2：节点2的启动配置文件
    runconfig.lua：一份描述服务端的拓扑结构的配置文件（存放的其实就是服务的位置之类的信息）

luaclib：存放一些C模块（.so 文件）


lualib：存放 Lua 模块
    service.lua：封装服务端这边的一些方法，使得代码更加简洁易懂
    （其实就是封装服务模块的使用方法）


service：存放各个服务的Lua代码

skynet：skynet框架

start.sh：启动服务器的脚本

---

## 3.4 封装以用的API

3.4 最后的小例子走的流程是：

首先走到 service/main.lua，里面创建了一个gateway服务（注意并且传了参数：gateway，1）；
因为配置文件里面设置了服务启动路径；
所以服务启动的时候，skynet 会去找到 service/[服务]/init.lua 作为服务启动的文件；

然后就启动服务了，就来到了 service/gateway/init.lua 文件里面；
里面用到了我们封装的API；
从 s.start(...) 开始（这里的...参数就是newserver时候传进来的 gateway 和 1）；
那么就又走到了 lualib/service.lua 里面；
调用 M.start() 去初始化（name 和 id），然后调用skynet.start(init)去调用gateway1服务里面的init；

那么问题来了，为什么在service.lua 里面的 init 里面的 M.init 不是空可以被调用，在start也没有给他初始化呀？？？
通过输出 print(tostring(M/s)) 可以发现：
在 service.lua 中的 M，和 gateway/init.lua 中的 s 其实是一个 table！！！
所以在 service.lua 中判断 M.init()，其实就是在看服务 gateway/init.lua 里面是否有init()！！！
（可能这是 lua 的特性？反正是没见过...有点神奇啊！）

然后就走到了 gateway/init.lua，然后输出，没了！

main.lua -> gateway/init.lua -> lualib/service.lua -> gateway/init.lua

--------------------------------------------------

# 3.5 - 3.11 开发底层框架




---


---


---


---


---






--------------------------------------------------

# 3.12 - 3.15 编写游戏逻辑




---


---


---


---


---


---


---





















