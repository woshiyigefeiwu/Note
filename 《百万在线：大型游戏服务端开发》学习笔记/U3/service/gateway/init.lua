local skynet = require "skynet"
local s = require "service"     -- 导入封装好的模块

function s.init()
    skynet.error("[start] " .. s.name .. " " .. s.id)
end

s.start(...)

