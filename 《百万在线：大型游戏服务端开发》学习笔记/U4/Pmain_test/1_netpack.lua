local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"

local queue    -- message queue


--��������
function process_connect(fd, addr)
     skynet.error("new conn fd:"..fd.." addr:"..addr)
     socketdriver.start(fd)
end

--�ر�����
function process_close(fd)
     skynet.error("close fd:"..fd)
end

--��������
function process_error(fd, error)
     skynet.error("error fd:"..fd.." error:"..error)
end

--��������
function process_warning(fd, size)
     skynet.error("warning fd:"..fd.." size:"..size)
end


--������Ϣ
function process_msg(fd, msg, sz)
     local str = netpack.tostring(msg,sz)
     skynet.error("recv from fd:"..fd .." str:"..str)
End

--�յ�����1����Ϣʱ
function process_more()
     for fd, msg, sz in netpack.pop, queue do
          skynet.fork(process_msg, fd, msg, sz)
     end
end

--����ײ㴫����SOCKET������Ϣ
function socket_unpack( msg, sz )
     return netpack.filter( queue, msg, sz)
end

--����ײ㴫����SOCKET������Ϣ
function socket_dispatch(_, _, q, type, ...)
     skynet.error("socket_dispatch type:"..(type or "nil"))
     queue = q
     if type == "open" then
          process_connect(...)
     elseif type == "data" then
          process_msg(...)
     elseif type == "more" then
          process_more(...)   
     elseif type == "close" then
          process_close(...)
     elseif type == "error" then
          process_error(...)
     elseif type == "warning" then
          process_warning(...)
     end
end


skynet.start(function()
     --ע��SOCKET������Ϣ
     skynet.register_protocol( {
          name = "socket",
          id = skynet.PTYPE_SOCKET,
          unpack = socket_unpack,
          dispatch = socket_dispatch,
     })
     --ע��Lua������Ϣ��skynet.dispatch �ԣ�
     --��������
     local listenfd = socketdriver.listen("0.0.0.0", 8888)
     socketdriver.start(listenfd)
end)