#!/usr/bin/env lua

local curl = require("cURL")
local json = require("cjson")
local socket = require("socket")
local argparse = require("argparse")

UserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36"
SuppressOutput = io.open("/dev/null", "w")
ServerListURL = "https://raw.githubusercontent.com/NeilasAnta/SpeedTestServerList/main/speedtest_server_list.json"
TestResult = "/tmp/result.json"
ServerList = "/tmp/serverList.json"
MyIpURL = "https://api.myip.com/"
LastUploadSpeed = 0
LastDownloadSpeed = 0



function Wait(seconds)
    local start = os.time()
    repeat
    until os.time() > start + seconds
end

function WriteFile(status, downSpeed, uploadSpeed, provider, host)
    -- // Downloading - 1
    -- // Uploading - 2
    -- // Finished download - 3
    -- // Finished upload - 4
    -- // Finished - 5
    -- // Searching for the best server - 6
    -- // Failed - anything else
    local file = io.open(TestResult, "w+")
    if file ~= nil then
        file:write(json.encode({
            status = status,
            downloadSpeed = downSpeed,
            uploadSpeed = uploadSpeed,
            provider = provider,
            host = host
        }))
        file:close()
    end
end

function TestDownload(server)
    local startTime = socket.gettime()
    local status, error = pcall(function()
        curl.easy()
            :setopt_useragent(UserAgent)
            :setopt_writefunction(SuppressOutput)
            :setopt_noprogress(false)
            :setopt_url(server.host .. "/download?size=500000000")
            :setopt_timeout(20)
            :setopt_progressfunction(function(dltotal, dlnow, uptotal, upnow)
                LastDownloadSpeed = math.floor(((dlnow / 1000000) * 8 / (socket.gettime() - startTime)) * 100) / 100
                WriteFile(1, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
            end)
            :perform()
            :close()
    end)

    if error == "[CURL-EASY][OPERATION_TIMEDOUT] Timeout was reached (28)"
        or error == "[CURL-EASY][PARTIAL_FILE] Transferred a partial file (18)"
        or error == "[CURL-EASY][PARTIAL_FILE] Error (18)"
        or error == nil then
        WriteFile(3, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
    elseif error ~= nil then
        WriteFile(0, 0, 0, server.provider, server.host)
        os.exit()
    end
end

function TestUpload(server)
    local startTime = socket.gettime()
    local status, error = pcall(function()
        curl.easy()
            :setopt_useragent(UserAgent)
            :setopt_writefunction(SuppressOutput)
            :setopt_noprogress(false)
            :setopt_url(server.host .. '/upload')
            :setopt_timeout(10)
            :setopt_httppost(curl.form():add_file("test_file", "/dev/zero"))
            :setopt_progressfunction(function(dltotal, dlnow, uptotal, upnow)
                LastUploadSpeed = math.floor(((upnow / 1000000) * 8 / (socket.gettime() - startTime)) * 100) / 100
                WriteFile(2, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
            end)
            :perform()
            :close()
    end)
    if error == "[CURL-EASY][OPERATION_TIMEDOUT] Timeout was reached (28)"
        or error == "[CURL-EASY][OPERATION_TIMEDOUT] Error (28)"
        or error == nil then
        WriteFile(4, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
    elseif error ~= nil then
        WriteFile(0, 0, 0, server.provider, server.host)
        os.exit()

    end
end

function GetServerList()
    local exists = io.open(ServerList, "r")
    if exists ~= nil and string.sub(exists:read("*all"), 1, 2) ~= "[{" or exists == nil then
        local file = io.open(ServerList, "w+")
        local status, error = pcall(function()
            curl.easy()
                :setopt_useragent(UserAgent)
                :setopt_url(ServerListURL)
                :setopt_writefunction(file)
                :perform()
                :close()
        end)
        if error ~= nil then
            WriteFile(0, 0, 0, "-", "-")
            os.exit()
        end
    end
end

function FindCountry()
    local country
    local status, error = pcall(function()
        curl.easy()
            :setopt_useragent(UserAgent)
            :setopt_url(MyIpURL)
            :setopt_writefunction(function(data) country = json.decode(data).country end)
            :perform()
            :close()
    end)
    if error ~= nil then
        WriteFile(0, 0, 0, "-", "-")
        os.exit()
    else
        return country
    end
end

function FindServersByCountry()
    local country = FindCountry()
    local servers = {}
    local file = io.open(ServerList, "r")
    if file ~= nil then
        local content = file:read("*all")
        if country ~= nil then
            local serverList = json.decode(content)
            for i, server in pairs(serverList) do
                if server.country == country then
                    table.insert(servers, server)
                end
            end
            if servers[1] ~= nil then return servers
            else
                WriteFile(0, 0, 0, "-", "-")
                os.exit()
            end
        else
            WriteFile(0, 0, 0, "-", "-")
            os.exit()
        end
    else
        return nil
    end
end

function FindBestServer()
    WriteFile(6, 0, 0, "-", "-")
    local servers = FindServersByCountry()
    local bestServer = nil
    local bestTime = 999999
    if servers ~= nil then
        for i, server in pairs(servers) do
            local status, error = pcall(function()
                local c = curl.easy()
                c:setopt_useragent(UserAgent)
                c:setopt_url(server.host)
                c:setopt_writefunction(SuppressOutput)
                c:setopt_timeout(1)
                c:perform()
                if c:getinfo_total_time() < bestTime then
                    bestTime = c:getinfo_total_time()
                    bestServer = server
                end
                c:close()
            end)
        end
        if bestServer ~= nil then return bestServer
        else
            WriteFile(0, 0, 0, "-", "-")
            os.exit()
        end
    else
        WriteFile(0, 0, 0, "-", "-")
        os.exit()
    end
end

local parser = argparse()
parser:option("--download", "Download test to the specified server"):argname("<host>")
parser:option("--upload", "Upload test to the specified server"):argname("<host>")
parser:option("--both", "Download and upload test to the specified server"):argname("<host>")
parser:flag("--automatic", "Download and upload test to the best server")
parser:flag("--findBest", "Find the closest server by latency")
parser:flag("--getServers", "Get server list")
parser:flag("--findCountry", "Find country by using location API")
parser:option("--provider", "b"):argname("<host>")
local args = parser:parse()

if (args.automatic) then
    GetServerList()
    local server = FindBestServer()
    TestDownload(server)
    Wait(2)
    TestUpload(server)
    WriteFile(5, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
elseif (args.findBest) then
    GetServerList()
    print(json.encode(FindBestServer()))
elseif (args.both and args.provider) then
    local server = {}
    server.host = args.both
    server.provider = args.provider
    TestDownload(server)
    Wait(2)
    TestUpload(server)
    WriteFile(5, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
elseif (args.download) then
    local server = {}
    server.host = args.download
    server.provider = "Unknown"
    TestDownload(server)
elseif (args.upload) then
    local server = {}
    server.host = args.upload
    server.provider = "Unknown"
    TestUpload(server)
elseif (args.both) then
    local server = {}
    server.host = args.both
    server.provider = "Unknown"
    TestDownload(server)
    Wait(2)
    TestUpload(server)
    WriteFile(5, LastDownloadSpeed, LastUploadSpeed, server.provider, server.host)
elseif (args.getServers) then
    GetServerList()
elseif (args.findCountry) then
    print(FindCountry())
end
