/*
这个是服务类；

不同的服务，本质上只是它的类型不同而已；
其他的操作基本上是一样的
*/

#pragma once
#include <queue>
#include <thread>
// #include <pthread>
#include "Msg.h"

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
    //取出一条消息
    shared_ptr<BaseMsg> PopMsg();
};