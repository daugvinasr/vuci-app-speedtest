local utils = require("vuci.utils")

ServerList = "/tmp/serverList.json"
TestResult = "/tmp/result.json"

local M = {}

function M.ReadResult()
    local content = utils.readfile(TestResult, "*l")
    return { content = content }
end

function M.FindCountry()
    local handle = io.popen("speedtest.lua --findCountry", 'r')
    local output = assert(handle:read('*a'))
    return { content = output }
end

function M.ReadServers()
    os.execute("speedtest.lua --getServers")
    local content = utils.readfile(ServerList, "*l")
    return { content = content }
end

function M.StartAutomaticTest()
    io.popen("speedtest.lua --automatic")
    local content = "Started a automatic download test"
    return { content = content}
end

function M.StartSpecifiedTest(params)
    local params = "speedtest.lua --both "..params.host..' --provider "'..params.provider..'"'
    io.popen(params)
    local content = params
    return { content = content}
end

return M
