/*
这个类是网络线程的对象，用于处理网络消息；

（监听端口，建立连接，接收数据，分发数据 等）
*/

#pragma once
using namespace std;
#include <sys/epoll.h>
#include <memory>
#include "Conn.h"

class SocketWorker { 
private:
    // epoll 对象的描述符
    int epollFd;

public:
    void Init();        // 初始化
    void operator()();  // 线程函数

public:
    // 这三个函数是对 fd 在 epoll 对象中的操作
    void AddEvent(int fd);      // 将 fd 添加 epoll 对象中
    void RemoveEvent(int fd);   // 将 fd 从 epoll 对象中删除
    void ModifyEvent(int fd, bool epollOut);    // 修改 fd

private:
    // 这三个函数是网络线程处理事件的具体逻辑
    void OnEvent(epoll_event ev);
    void OnAccept(shared_ptr<Conn> conn);
    void OnRW(shared_ptr<Conn> conn, bool r, bool w);
};
