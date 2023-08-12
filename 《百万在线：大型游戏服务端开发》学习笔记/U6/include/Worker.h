/*
worker 对象；
这里会给每条线程配一个 worker 对象；

其实就是一个线程对应一个 worker 对象，
这样更加面向对象吧...可能...

线程的操作指的就是 worker 对象的操作
*/

#pragma once
#include <thread> 
#include "Sunnet.h"
#include "Service.h"
class Sunnet;

using namespace std;

class Worker { 
public:
    int id;             // 编号
    int eachNum;        // 每次处理多少条消息
    void operator()();  // 线程函数
private:
    //辅助函数
    void CheckAndPutGlobal(shared_ptr<Service> srv);
};