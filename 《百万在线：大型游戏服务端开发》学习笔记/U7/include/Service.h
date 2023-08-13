/*
这个是服务类；

不同的服务，本质上只是它的类型不同而已；
其他的操作基本上是一样的

第七章，c++和lua的相互调用：
这里需要封装一些 lua 调用的接口，以及调用 lua 时的代码
*/

#pragma once
#include <queue>
#include <thread>
#include "Msg.h"
#include "ConnWriter.h"
#include <unordered_map>

// 因为lua使用c语言写的，所以这里注意用extern包裹一下
extern "C"  {  
    #include "lua.h"  
    #include "lauxlib.h"
    #include "lualib.h"  
}  

using namespace std;

class Service {
public:
    //为效率灵活性放在public
    
    uint32_t id;                //唯一id
    shared_ptr<string> type;    //类型

    // 是否正在退出
    bool isExiting = false;

    /*
    消息列表：    
        每个服务都有自己的消息队列，工作线程可以从当前服务中读取消息；
        或者把其他服务的消息加入到指定服务的消息队列中；
        从而达到消息传递的效果。
    */
    queue<shared_ptr<BaseMsg>> msgQueue;
    pthread_spinlock_t queueLock;

    //标记是否在全局队列  true:在队列中，或正在处理
    bool inGlobal = false;
    pthread_spinlock_t inGlobalLock;

    //业务逻辑（仅测试使用）（用于关联 socket fd 和 写 自定义的缓冲区）
    unordered_map<int, shared_ptr<ConnWriter>> writers;
public:       
    //构造和析构函数
    Service();
    ~Service();

    //回调函数（编写服务逻辑）
    void OnInit();
    void OnMsg(shared_ptr<BaseMsg> msg);
    void OnExit();

    //插入消息
    void PushMsg(shared_ptr<BaseMsg> msg);

    //执行消息
    bool ProcessMsg();
    void ProcessMsgs(int max);  

    //全局队列
    void SetInGlobal(bool isIn);

private:
    // 取出一条消息
    shared_ptr<BaseMsg> PopMsg();

    // 消息处理方法
    void OnServiceMsg(shared_ptr<ServiceMsg> msg);
    void OnAcceptMsg(shared_ptr<SocketAcceptMsg> msg);
    void OnRWMsg(shared_ptr<SocketRWMsg> msg);

    // 下面三个是在 OnRWMsg 下的分支
    void OnSocketData(int fd, const char* buff, int len);
    void OnSocketWritable(int fd);
    void OnSocketClose(int fd);

private:
    lua_State *luaState;    // Lua虚拟机（时刻记住它对应一个lua栈）
};