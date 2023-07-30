local skynet = require "skynet"
local pb = require "protobuf"
local mysql = require "skynet.db.mysql"
local db  --���ݿ����ʡ���������ݿ�Ĵ���

function test5()
    local playerdata = {}
    local res = db:query("select * from player where playerid = 105")
    if not res or not res[1] then
        print("loading error")
        return false
    end
    playerdata.coin = res[1].coin
    playerdata.name = res[1].name
    playerdata.last_login_time = res[1].last_login_time

    print("coin:"..playerdata.coin)
    print("name:"..playerdata.name)
    print("time:"..playerdata.last_login_time)
end

function test6()
    pb.register_file("./storage/playerdata.pb")
    --����
    local playerdata = {
        playerid = 109,
        coin = 97,
        name = "Tiny",
        level = 3,
        last_login_time = os.time(),
	}
	--���л�
    local data = pb.encode("playerdata.BaseInfo", playerdata)
	print("data len:"..string.len(data))
	--�������ݿ�
    local sql = string.format("insert into baseinfo (playerid, data) values (%d, %s)", 109, mysql.quote_sql_str(data))
	local res = db:query(sql)
	--�鿴�洢���
    if res.err then
        print("error:"..res.err)
    else
        print("ok")
    end
end


function test7()
	pb.register_file("./storage/playerdata.pb")
	--��ȡ���ݿ⣨���Զ�ȡʧ�ܵ������
    local sql = string.format("select * from baseinfo where playerid = 109")
    local res = db:query(sql)
	--�����л�
    local data = res[1].data
    print("data len:"..string.len(data))
    local udata = pb.decode("playerdata.BaseInfo", data)
    if not udata then
        print("error")
        return false
	end
    --���
    local playerdata = udata
    print("coin:"..playerdata.coin)
    print("name:"..playerdata.name)
    print("time:"..playerdata.last_login_time)
end

skynet.start(function()
    test5()
	--test6()
	--test7()
end)