local skynet = require "skynet"
local pb = require "protobuf"


--protobuf�������
function test4()
    pb.register_file("./proto/login.pb")
    --����
    local msg = {
        id = 101,
        pw = "123456",
    }
    local buff = pb.encode("login.Login", msg)
    print("len:"..string.len(buff))
    --����
    local umsg = pb.decode("login.Login", buff)
    if umsg then
        print("id:"..umsg.id)
        print("pw:"..umsg.pw)
    else
        print("error")
    end
end



skynet.start(function()
    test4()
end)