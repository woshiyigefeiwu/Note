/*
这个 Sunnet 就是整个架构的基础；
管理所有的线程和服务
*/

#pragma once
#include <vector>
// #include <pthread>
#include "Worker.h"
#include "Service.h"
#include <unordered_map>
#include "SocketWorker.h"
#include "Conn.h"

// 前向声明，防止循环引用
class Worker;

class Sunnet {

public:
    //单例（全局只有一个）
    static Sunnet* inst;

public:
    Sunnet();       //构造函数
    void Start();   //初始化并开始
    void Wait();    //等待运行

    //增删服务
    uint32_t NewService(shared_ptr<string> type);
    void KillService(uint32_t id);     //仅限服务自己调用

    //发送消息
    void Send(uint32_t toId, shared_ptr<BaseMsg> msg);  

    //全局队列操作
    shared_ptr<Service> PopGlobalQueue();
    void PushGlobalQueue(shared_ptr<Service> srv);

    //让工作线程等待（仅工作线程调用）
    void WorkerWait();
    
    // 仅测试
    shared_ptr<BaseMsg> MakeMsg(uint32_t source, char* buff, int len);

    // 增删查Conn
    int AddConn(int fd, uint32_t id, Conn::TYPE type);
    shared_ptr<Conn> GetConn(int fd);
    bool RemoveConn(int fd);

    // 网络连接操作接口（用原始read write）
    int Listen(uint32_t port, uint32_t serviceId);
    void CloseConn(uint32_t fd);
    
    // 对外Event接口
    void ModifyEvent(int fd, bool epollOut);

private:
    // 工作线程
    int WORKER_NUM = 3;              //工作线程数（配置）
    vector<Worker*> workers;         //worker对象
    vector<thread*> workerThreads;   //线程

    // Socket线程
    SocketWorker* socketWorker;
    thread* socketThread;

    //服务列表
    unordered_map<uint32_t, shared_ptr<Service>> services;
    uint32_t maxId = 0;              //最大ID
    pthread_rwlock_t servicesLock;   //读写锁
    
    /*
    全局队列：
        存放有消息待处理的服务，能使得工作线程快速工作（直接取就行）
    */
    queue<shared_ptr<Service>> globalQueue;
    int globalLen = 0;               //队列长度
    pthread_spinlock_t globalLock;   //锁
    
    /*
    休眠和唤醒：
        用于降低延迟，当工作线程处理完服务消息之后，
        可以被挂起，等待被唤醒
    */
    pthread_mutex_t sleepMtx;
    pthread_cond_t sleepCond;
    int sleepCount = 0;        //休眠工作线程数 

    // Conn列表
    unordered_map<uint32_t, shared_ptr<Conn>> conns;
    pthread_rwlock_t connsLock;   //读写锁
    
private:
    //开启工作线程
    void StartWorker();
    
    //唤醒工作线程
    void CheckAndWeakUp();
    
    //开启Socket线程
    void StartSocket();

    //获取服务
    shared_ptr<Service> GetService(uint32_t id);
};

