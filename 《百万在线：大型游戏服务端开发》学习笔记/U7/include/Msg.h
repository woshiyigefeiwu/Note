/*
消息类，定义各种消息；

第五章搞了一种消息，ServiceMsg：
主要用于服务之间的消息通信；

第六章增加了两种消息：SocketAcceptMsg，SocketRWMsg：
用于网络模块，主要是对 socket 和 服务 之间的通信；
*/

#pragma once        // 可以规定该文件只被编译一次
#include <memory>
using namespace std;

// 消息基类
class BaseMsg
{
public:
    enum TYPE
    {
        SERVICE = 1,
        SOCKET_ACCEPT = 2,  // 连接的消息
        SOCKET_RW = 3,      // 数据读写的消息
    };

    uint8_t type;           //消息类型
    char load[999999]{};    //用于检测内存泄漏
    virtual ~BaseMsg(){};
};

//服务间消息
class ServiceMsg : public BaseMsg  {
public: 
    uint32_t source;        //消息发送方
    shared_ptr<char> buff;  //消息内容
    size_t size;            //消息内容大小
};

// 新连接
class SocketAcceptMsg : public BaseMsg {
public: 
    int listenFd;
    int clientFd;
};

// 可读可写
class SocketRWMsg : public BaseMsg {
public: 
    int fd;
    bool isRead = false;    // 是否读
    bool isWrite = false;   // 是否写
};

