# 前言

> [!NOTE] 前言
> 
> 看完了这本书下面总结一下知识点。
> 
> 我个人把他分为两个部分：
> 
> 第一部分是 1 ~ 7 章，讲的是 **如何 搭建 / 仿写 一个服务器**；
> 
> 第二部分是 8 ~ 1 章，主要讲的是一些**其他内容优化**；
> 
> 下面就这两部分开始总结。

ps：不总结不知道...原来有这么多东西...麻了...

------------------------

# 第一部分：

## **Sunnet 类：** 
- 架构的基础，用于控制整个架构

### **数据成员：**

- 主体
	- 一个 Sunnet* 对象 inst 全局一个；
	- 这个就是 Sunnet 系统的基础；
- 工作线程
	- 一个 workers 数组，表示 worker 对象的集合；
	- 一个workerThreads 数组，表示工作线程；
	- 一个 工作线程 对应 一个 worker 对象；
	- 工作线程用于执行服务的消息处理；
- 网络线程
	- 一个 SocketWorker 对象；
	- 一个 socketThread，和 SocketWorker 对应；
	- 用于处理网络消息；
- 服务列表
	- 一个unmap，用于存放所有的服务，以 id - 服务 的形式；
	- 一个读写锁，实现对这个服务列表的线程同步；
	- 因为大部分情况下是读取而已，所以用读写锁提高效率；
- 全局队列
	- 一个 queue，存放所有 有未处理消息的服务；
	- 一个 自旋锁 globalLock，实现线程同步；
	- 有了这个 queue，工作线程直接从这个队列里面取服务执行就行，方便高效；
	- 因为等待的时间比较短，所以使用自旋锁，提高效率；
- Conns 列表
	- 一个 unordered_map 的 conns，用于存放所有的链接；
	- 一个 读写锁 connsLock，实现线程同步；
- 工作线程的调度
	- 一个互斥锁，sleepMtx；
	- 一个条件变量，sleepCond；
	- 一个工作线程休眠的数量，sleepCount；
	- 通过互斥锁和条件变量能够唤醒和挂起工作线程；


### **成员函数：**

- Sunnet()
	- 构造函数；
	- 用于创建全局的 Sunnet 对象 inst，单例模式；
- Start()
	- 开始函数；
	- 用于初始化一些锁 和 调用开启线程函数；
- Wait()
	- 等待函数；
	- 工作线程的退出，调用 join；
- NewService()
	- 通过服务类型，创建一个服务，并放入服务列表中；
- KillService()
	- 通过服务id，删除服务，只有服务自己能调用；
- Send()
	- 传进来一个服务 id，一个信息，向这个服务发送信息；
	- 首先通过 id 从服务列表services里面取出服务，然后向这个服务的消息队列中push该条消息；
	- 接着将这个服务放入全局队列中，然后唤醒一个线程取处理它；
- PopGlobalQueue()
	- 从全局队列中取出服务；
- PushGlobalQueue()
	- 往全局队列中push服务；
- WorkerWait()
	- 让工作线程进入休眠（仅工作线程调用）
- MakeMsg() 
	- 创建一个消息
- AddConn()
	- 创建一个 Conn 对象，并添加到 Conns 列表中
- GetConn()
	- 传进来一个 fd，从 Conns 中取出对应的 Conn；
- RemoveConn()
	- 传进来一个fd，从 Conns 中删除对应的连接
- Listen()
	- 用于监听连接，一般服务启动的时候会调用；
	- 创建监听fd，以及对应的 Conn 对象；
	- 并将 fd 加入 epoll，将 Conn 对象加入 Conns 列表；
- ModifyEvent(int fd, bool epollOut)
	- 修改 fd 监听的事件类型；
- StartWorker()
	- 开启工作线程函数；
	- 创建 Worker 对象 和 线程，并开始运行；
- CheckAndWeakUp()
	- 唤醒工作线程；
- StartSocket()
	- 开启Socket线程；
	- 创建一个网络工作对象，并初始化，然后开启线程；
- GetService()
	- 通过服务的id，从全局的服务列表中获取服务；

------------------------

## **Worker 类：**
- 工作类，一个线程对应一个Worker对象，共同组成工作线程；
- 用于执行服务的消息处理；


### **数据成员：**

- id
	- 编号，Worker 对象的标识
- int eachNum
	- 表示 Worker 对象 每次处理多少条消息；

### **成员函数：**

- void operator()()
	- 线程函数
- CheckAndPutGlobal()
	- 检查服务是否还有未处理的消息，有的话放入全局队列

------------------------

## **SocketWorker 类：**
- 网络工作对象，用于处理网络数据；

### **数据成员：**
- epoll 对象
	- 用 epollFd 表示

### **成员函数：**
- Init() 
	- 初始化函数，创建一个 epoll 对象
- operator()()
	- 线程函数，循环 epoll_wait 检测是否有事件触发，有的话取出来并调用 OnEvent() 处理
- OnEvent()
	- 基础的事件处理，在函数里面根据不同的事件类型进行事件的分发
- OnAccept(shared_ptr<Conn> conn)
	- 当监听事件（文件描述符是 ListenFd）触发时会调用这个函数处理；
	- 传进来一个conn连接对象，接收连接得到client的文件描述，将它加入epoll，并创建新的conn对象，加入conns中；
	- 创建一个 SocketAcceptMsg 消息，并向源服务发送该消息；
	- 这个conn怎么来的，后面把流程全部捋一遍就知道了！
- OnRW(shared_ptr<Conn> conn, bool r, bool w)
	- 当普通事件触发时会调用这个函数；
	- 创建一个 SocketRWMsg 消息，并向源服务发送该消息；
- AddEvent()
	- 将 fd 添加到epoll对象中
- RemoveEvent()
	- 将fd 从epoll对象中删除
- ModifyEvent()
	- 修改 fd 的事件触发类型;

------------------------

## **Service 类：**
- 服务类，用于创建不同类型的服务；
- 是一个挺核心的东西

### **数据成员：**
- id
	- 唯一标识一个服务
- shared_ptr<string> type
	- 表示服务的类型
- bool isExiting;
	- 表示当前服务是否正在退出;
- queue<shared_ptr<BaseMsg>> msgQueue;
	- 服务的消息队列，用于存放当前服务的消息；
	- 工作线程可以从当前服务中读取消息，也可以将其他服务的消息添加到当前服务的消息队列中；
- inGlobal
	- 标记是否在全局队列中，或者正在处理;
- inGlobalLock
	- 锁住上面的标记，为什么要这个呢？
	- 注意上面这个标记还有是否正在处理的意思；
	- 就是说，一个服务在全局队列中，在处理完之前可能还在全局队列中，那么就有有可能有多个线程同时访问到这个服务；所以需要对这个变量上锁
- unordered_map<int, shared_ptr<ConnWriter>> writers;
	- 自定义的写缓冲区的集合，一个fd对应一个写缓冲区；
	- 用于关联 socket fd 和 写 自定义的缓冲区；
- lua_State *luaState;    
	- Lua虚拟机（时刻记住它对应一个lua栈）
	- 一个服务对应一个 lua 虚拟机

### **成员函数：**
- Service()
	- 构造函数，初始化各种锁；
- ~Service()
	- 销毁各种锁
- OnInit()
	- 回调函数，service 类中最重要的一个函数；
	- 在这里面会调用对应类型服务的 OnInit() 的 lua 代码；
	- 具体的讲：
		- luaL_newstate()：新建一个 lua 虚拟机；
		- luaL_openlibs(luaState)：开启 lua 的系统库;
		- LuaAPI::Register(luaState)：注册Sunnet系统API，这样 lua 才能调用 C++ 的接口
		- luaL_dofile(luaState, filename.data())：执行对应的 lua 文件
		- 调用 lua 函数：以此将 lua 函数和参数压入 lua 栈，然后lua_pcall 执行 lua 函数；
- OnMsg()
	- 当服务收到消息的时候会触发；消息分发
	- 根据不同的消息类型调用不同的方法；
		- SERVICE 类型 调用 OnServiceMsg()
		- SOCKET_ACCEPT 类型 调用 OnAcceptMsg()
		- SOCKET_RW 类型 调用 OnRWMsg()
- OnExit()
	- 当服务关闭时调用；
	- 首先调用 lua 的关闭函数，接着关闭 lua 虚拟机
- PushMsg()
	- 往当前服务的消息队列中插入消息
- ProcessMsg()   ProcessMsgs()
	- 执行消息的函数；
	- 从消息队列中取出一条消息，然后调用 上面的 OnMsg() 将消息分发出去；
- SetInGlobal()
	- 将当前服务设置在全局队列中（改变一下标记）
- shared_ptr<BaseMsg> PopMsg();
	- 从消息队列中取出一条消息;
- OnServiceMsg()
	- 接收到其他服务发送过来的消息的时候会被调用；
	- 在函数里面，调用了 lua 函数的 OnServiceMsg()；
	- 在 上层的 lua 的 OnServiceMsg() 实现对消息的逻辑处理;
- OnAcceptMsg()
	- 接收到新连接的时候会被调用
	- 在函数里面，调用了 lua 函数的 OnAcceptMsg()；
	- 在 上层的 lua 的 OnAcceptMsg() 实现对消息的逻辑处理;
- OnRWMsg()
	- 但普通套接字可以读写的时候会被调用；
	- 通过消息的读写标志位来进行不同的操作，消息分发；
		- 可读：调用 OnSocketData(fd, buff, len)
		- 可写：调用 OnSocketWritable(fd);
		- 发生错误：调用 OnSocketClose(fd);
- OnSocketData(int fd, const char* buff, int len);
	- 套接字可读时消息被分发到这里；
	- 作用是 对客户端的数据进行处理；
	- 具体的逻辑还是交给上层lua去处理；
	- 会调用上层 lua 的 OnSocketData() 函数；
- OnSocketWritable(int fd);
	- 套接字可写时消息被分发到这里；
	- 传进来一个fd，通过这个fd找到它对应的自定义写缓冲区；
	- 将数据写到自定义的写缓冲区中；
- OnSocketClose()
	- 关闭时会走这里，还是会调用上层的lua进行逻辑处理；

------------------------

## **BaseMsg 消息基类：**
- TYPE
	- 一个枚举类型，表示消息的类型；
- virtual ~BaseMsg(){};
	- 一个虚析构函数，这样才能完全释放

**ServiceMsg 类：继承于 BaseMsg**
- source
	- 消息发送方；
- shared_ptr<char> buff
	- 消息内容
- size_t size;
	- 消息的大小

**SocketAcceptMsg 类：继承于 BaseMsg**
新连接的消息；
- listenFd：监听的文件描述符
- clientFd：客户端的文件描述符

**SocketRWMsg 类：继承于 BaseMsg**
读写通知消息
- fd：文件描述符
- bool isRead：是否读
- bool isWrite：是否写

------------------------

## **Conn 类**：
连接类，用于存放一条连接的基本信息；
- TYPE：
	- 一个枚举类型，表示是监听的连接还是普通的连接；
- fd;
	- 连接的文件描述符；
- serviceId
	- 这条连接对应的服务；


------------------------

## **ConnWriter 类：**
自定义的写缓冲区类，一条连接对应一个写缓冲区；
- Class WriteObject
	- 写缓冲区是用一个 list 结构，list上面有一些节点，一个 WriteObject 就是一个节点，表示一个待处理的数据；
		- start：开始处理的位置
		- len：长度
		- buff：数据
- Class ConnWriter
	- 这个就是自定义的写缓冲区了
	- 数据成员
		- fd：文件描述符
		- isClosing：表示是否正在关闭
		- list<shared_ptr<WriteObject>> objs;
			- 一个双向链表，上面存了一些待处理的数据；
	- 成员函数
		- EntireWrite(shared_ptr<char> buff, streamsize len);
			- 对外提供的发送数据的接口，分两种情况
			- 没有数据带写入处理，则调用 EntireWriteWhenEmpty，尝试写入
			- 有数据待写入处理，则调用 EntireWriteWhenNotEmpty，将数据添加到链表后面
		- LingerClose()
			- 关闭连接时会调用这个函数；
			- 里面会把未处理的数据发送完再关闭连接；
		- OnWriteable()
			- 服务对象检测到有数据可以写的时候会调用这个函数；
			- 调用 WriteFrontObj() 函数，将数据通过write发送出去
		- EntireWriteWhenEmpty() 
			- 当要写东西，且自定义写缓冲区没有数据的时候，会被调用；
			- 尝试将数据发送出去，如果没发送完，则创建一个节点，将剩余的数据塞到节点里面；
			- 然后将节点挂到自定义的写缓冲区的链表上；
			- 最后记得将对应的文件描述符变成监听写事件；
		- EntireWriteWhenNotEmpty()
			- 当要写东西，且自定义写缓冲区不为空，会被调用；
			- 直接创建一个节点，将所有的数据塞进去，然后挂到链表上；
		- WriteFrontObj() 
			- 尝试发送一次数据，该节点发送完了则返回true，否则返回false；
			- 发送不会会更新节点的状态（比如这条信息下一次需要从哪个地方开始发送）

------------------------

## LuaAPI 类：
用于定义一些 lua 调用 c++ 的函数；
也就说向 lua 提供 c++ 接口；
- static void Register(lua_State *luaState);
	- 注册 lua 模块，lua 想要调用的c++ 接口都得在这里注册；

------------------------









------------------------

# 第二部分：

## 第 8 章：同步算法

> [!NOTE] 同步算法
> 
> 直接看这一篇就行，讲的挺不错的：
> 
> [# 网络游戏知识——【同步算法】](https://blog.csdn.net/qq_53045580/article/details/130836125?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522169242782316800192288097%2522%252C%2522scm%2522%253A%252220140713.130102334..%2522%257D&request_id=169242782316800192288097&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~all~sobaiduend~default-1-130836125-null-null.142^v93^chatgptT3_2&utm_term=%E5%90%8C%E6%AD%A5%E7%AE%97%E6%B3%95&spm=1018.2226.3001.4187)
> 
> 问题分析，同步会带来一些问题，**瞬移、顿挫、打不中**；
> 
> **顿挫 和 打不中** 本质上来说是因为 **网络的 延迟和抖动** 导致的
> 
> **服务器：增加同步帧率**
> 
> **客户端：插值算法，缓存队列**
> 


> [!NOTE] 同步方式：帧同步、状态同步、状态帧同步
> 
> （箭头前面表示客户端发送给服务器是消息是什么，箭头后面表示的是服务器回复给客户端是什么）
> 
> [# 【网络同步】浅析帧同步和状态同步](https://zhuanlan.zhihu.com/p/357973435)
> 
> **状态同步（状态 -> 状态 / 指令 -> 状态）：**
> 
> 客户端发送状态给服务器，服务器运算之后，把结果的状态发送给所有客户端；
> 
> **优点：**
> 不容易作弊，比较公平
> 
> **缺点：**
> 服务器压力大，有一定延迟，消耗流量大，浪费客户端资源，不好回放；
> 
> ---
> 
> **注意这里状态同步还分为两种：**
> 
> **状态 -> 状态**：客户端算出状态，发送给客户端，客户端校验，然后将状态再转发给其他的客户端；
> 
> **指令 -> 状态**：客户端只提供指令，服务器计算出状态，然后将状态发送给其他的客户端；
> 
> ---
> 
> **帧同步（指令 -> 指令）：**
> 客户端把指令 发送给服务器，服务器把在一帧的时间里面收集到的指令发送给所有客户端，然后客户端去算，然后表现出来；
> 
> **优点：**
> 实时性比较好，消耗流量小，比较容易做回放，服务器压力小；
> 
> **缺点：**
> 但是比较依赖客户端，和网络质量，比较容易作弊；
> 
> ![[image-20230819165036778.png]]
> 
> 



## 第 9 章：热更新

演变：

1. 重启进程

2. 切换进程
（1）fork exec 函数
（2）通过网关 
（需要多个进程相互配合，而且要实现进程级别的无状态或者能完全保存和回复状态）

3. 动态库
（麻烦且容易出错）

4.  脚本语言
lua热更新可以看看lua的那本书


## 第 10 章：防外挂













