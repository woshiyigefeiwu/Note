print("run lua init.lua")

function test_chat()
    sunnet.NewService("chat")   -- lua 调用 c++ 接口，创建一个chat服务
end

function test_pingpong()
    local ping1 = sunnet.NewService("ping")
    print("[lua] new service ping1: "..ping1)

    local ping2 = sunnet.NewService("ping")
    print("[lua] new service ping1: "..ping2)

    local pong = sunnet.NewService("ping")
    print("[lua] new service pong: "..pong)

    sunnet.Send(ping1,pong,"start");
    sunnet.Send(ping2,pong,"start");
end

-- sunnet 底层在启动main服务的时候，c++会调用这里的lua代码
function OnInit(id)
    print("[lua] main OnInit id: "..id);

    -- test_pingpong()
    test_chat()
end

function OnExit()
    print("[lua] main OnExit")
end


