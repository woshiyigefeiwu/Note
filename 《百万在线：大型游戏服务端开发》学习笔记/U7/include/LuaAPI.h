/*
这里面的函数都是lua调用c++时要用到的函数；
需要在这里面注册一下；
*/

#pragma once

extern "C"  {  
    #include "lua.h"
}  

using namespace std; 

class LuaAPI {
public:
    static void Register(lua_State *luaState);

    // 这里返回值int表示的是返回值的个数
    static int NewService(lua_State *luaState);
    static int KillService(lua_State *luaState);
    static int Send(lua_State *luaState);

    static int Listen(lua_State *luaState);
    static int CloseConn(lua_State *luaState);
    static int Write(lua_State *luaState);
};