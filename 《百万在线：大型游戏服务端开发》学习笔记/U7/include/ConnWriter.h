/*
这个是自定义的写缓冲区，用于应对发送大数据的情况；

每个 socket 关联一个写缓冲区对象;

这个很有意思奥：

每一个 socket fd 对应一个自定义的写缓冲区；

当fd可写时，通过判断写缓冲区是否为空进行不同的处理：
为空：则尝试着直接发送，如果有剩的则加载自定义的缓冲区的末尾；
不为空：则添加到自定义的缓冲区的末尾，并且将fd设置为写监听；
        当fd再次可写的时候就会调用 service.cpp 中的 OnSocketWritable()
        进一步走到OnWriteable()，将自定义写缓冲区中的内容先发出去！
*/

#pragma once
#include <list>
#include <stdint.h>
#include <memory>
using namespace std; 

// 写缓冲区中的数据结构
class WriteObject {
public:
    streamsize start;
    streamsize len;
    shared_ptr<char> buff;
};

class ConnWriter {
public:
    int fd;
private:
    //是否正在关闭
    bool isClosing = false;
    list<shared_ptr<WriteObject>> objs;  //双向链表
public:
    void EntireWrite(shared_ptr<char> buff, streamsize len);
    void LingerClose(); //全部发完完再关闭
    void OnWriteable();
private:
    void EntireWriteWhenEmpty(shared_ptr<char> buff, streamsize len);
    void EntireWriteWhenNotEmpty(shared_ptr<char> buff, streamsize len);
    bool WriteFrontObj();
};