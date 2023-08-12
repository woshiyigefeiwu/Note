/*
自定义的一个连接类，用于关联 fd 和 服务
*/

#pragma once
using namespace std; 

class Conn {
public:
    enum TYPE {          //消息类型
        LISTEN = 1, 
        CLIENT = 2,
    }; 

    uint8_t type;
    int fd;
    uint32_t serviceId;
};