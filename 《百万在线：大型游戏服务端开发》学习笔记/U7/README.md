第七章看完了，下面开始整理一下代码：

这一章很有意思奥，将的是 c++ 和 lua 相互调用

c++ 用来实现底层，lua 用来写服务的具体逻辑

---------------------------------

新增了两个文件夹， 3rd 和 service；

3rd：用于存放 lua 的源码；

service：用于存放 lua 实现的各个服务的具体逻辑代码

---------------------------------

这里需要重点理解 lua 虚拟机 和 lua 栈；

一个lua虚拟机 对应 一个lua栈；

所有的c++ lua相互调用都是基于这个lua栈的，非常重要；

在具体的操作中，又很像汇编语言，通过对这个lua栈的直接操作，达到相互调用的效果；

---------------------------------

c++ 调 lua：

    1. 首先要有一个lua虚拟机（定义lua虚拟机时就规定了使用哪个lua文件，lua虚拟机对应一个lua栈）
    
    2. 将要执行的lua函数压入栈；
    
    3. 将函数的参数压入栈
    
    4. 然后调用lua函数执行就行（这里将 lua 栈中的函数和参数取出，然后执行，最好将返回结果压入lua 栈中）

&emsp;
&emsp;

几个API：

    int lua_getglobal(lua_State *L, const char *name);
    
    将 name 类型的全局变量压入栈中，并返回该值的类型。（用于压入函数）
&emsp;
    void lua_pushinteger(lua_State *L, lua_Integer n);
    
    将整数 n 压入栈中
&emsp;
    int lua_pcall(lua_State *L, int nargs, int nresults, int msgh);
    
    调用一个 lua 方法，nargs是传入的参数个数，nresults是返回值的个数；
    
    msgh用于指定调用失败则应该采取什么样的处理方法，0为默认；
&emsp;
    const char *lua_tostring(lua_State *L, int index);
    
    将lua栈中的第index个位置的值转换为一个c字符串

--------------------------------------------------

lua 调用 c++：

    1. 首先c++方面需要注册一下lua函数（相当于就是c++函数和lua函数绑定）

    2. 然后在c++代码中，将lua中的参数取出

    3. 然后调用c++方的函数执行就行，执行完把返回值压入lua栈中

    4. 这样子lua方就能调用c++的函数了

&emsp;
&emsp;

几个API：

    int lua_gettop(lua_State *L);

    返回lua栈顶元素的索引，相当于是返回了lua栈的元素个数
&emsp;
    int lua_isstring(lua_State *L, int index)

    判断lua栈中的第index和元素的值是否是 字符串或者数字 ，是返回1，否返回0
&emsp;
    const char *lua_tolstring(lua_State *L, int index, size_t *len)
    
    将lua栈中的第index个元素的值转换为字符串，并将长度赋值给len



