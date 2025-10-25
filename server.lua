---@diagnostic disable: duplicate-set-field

local tinyyaml = require("libraries.tinyyaml")
local LibDeflate = require("libraries.CC-Archive.LibDeflate")

-- Open modem
peripheral.find("modem", rednet.open)

local dir = fs.getDir(shell.getRunningProgram())
local files = fs.combine(dir, "files")

if not fs.exists(dir .. "/config.yaml") then
    print("Creating config.yaml with default config")
    print("Make sure to change your hostname in the file!")
    fs.copy(dir .. "/server.default.yaml", dir .. "/config.yaml")
end

-- Load config
local file = fs.open(dir .. "/config.yaml", "r")
local config = tinyyaml.parse(file.readAll())
file.close()

local hostname = config.hostname or "default.com"

local SERVER_CONFIG = {
    defaultTimeoutSeconds = config.defaultTimeoutSeconds or 0.25,
    hookInstructionCount = config.hookInstructionCount or 10000,
    maxRequestsPerWindow = config.maxRequestsPerWindow or 6,
    requestWindowSeconds = config.requestWindowSeconds or 10,
    maxMessageBytes = config.maxMessageBytes or (32 * 1024),
    schedulerTick = config.schedulerTick or 0.1,
    maxConcurrentDynamic = config.maxConcurrentDynamic or 6,
    cleanupInterval = config.cleanupInterval or 30,
    cacheStaticPages = config.cacheStaticPages ~= false,
    logPrefix = config.logPrefix or "[theccwww] "
}

print("Starting server as " .. hostname)
print("Files dir: " .. files)

if not fs.exists(files) then fs.makeDir(files) end
if not fs.exists(files .. "/404.lua") and fs.exists(files .. "/404.default.lua") then
    fs.copy(files .. "/404.default.lua", files .. "/404.lua")
end
if not fs.exists(files .. "/index.lua") and fs.exists(files .. "/index.default.lua") then
    fs.copy(files .. "/index.default.lua", files .. "/index.lua")
end

rednet.host("theccwww", hostname)

local theccwwwserver = {}
theccwwwserver.method = "GET"
theccwwwserver.path = "/"
theccwwwserver.query = {}
theccwwwserver.headers = {}
theccwwwserver.body = ""
theccwwwserver.statusCode = 200
theccwwwserver.redirect = nil
theccwwwserver.log = function(msg) print(SERVER_CONFIG.logPrefix .. msg) end
theccwwwserver.uuid = function()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

local function parseQuery(query)
    local t = {}
    if not query or query == "" then return t end
    for k, v in string.gmatch(query, "([^&=]+)=([^&=]+)") do t[k] = v end
    return t
end

local function parseHeaders(headerString)
    local headers = {}
    if not headerString then return headers end
    for line in string.gmatch(headerString, "[^\r\n]+") do
        local k, v = string.match(line, "(.-):%s*(.*)")
        if k and v then headers[k:lower()] = v end
    end
    return headers
end

local function safeReadFile(path)
    local f = fs.open(path, "r")
    if f then
        local content = f.readAll()
        f.close()
        return content
    else
        theccwwwserver.log("[ERROR] Could not open file: " .. path)
        return "[Error] Could not read file."
    end
end

local pageCache = {}
local function safeReadFileCached(path)
    if SERVER_CONFIG.cacheStaticPages and pageCache[path] then return pageCache[path] end
    local content = safeReadFile(path)
    if SERVER_CONFIG.cacheStaticPages then pageCache[path] = content end
    return content
end

local function parseRequest(raw)
    local method, pathWithQuery, protocol = string.match(raw, "^(%S+)%s+(%S+)%s+(%S+)")
    if not method then
        method = "GET"
        pathWithQuery = raw
        protocol = "THECCWEB/1"
    end
    local page, query = string.match(pathWithQuery, "^/?([^?]*)%??(.*)$")
    if page == "" then page = nil end
    local params = query and parseQuery(query) or {}
    local headerString, body = string.match(raw, "^(.-)\r?\n\r?\n(.*)$")
    local headers = headerString and parseHeaders(headerString) or {}
    return method, page, params, headers, body or ""
end

local httpStatus = {
    [200] = "OK",
    [201] = "Created",
    [302] = "Found",
    [400] = "Bad Request",
    [403] = "Forbidden",
    [404] = "Not Found",
    [429] = "Too Many Requests",
    [500] = "Internal Server Error",
    [503] = "Service Unavailable"
}

local function isPathInside(base, candidate)
    local b = fs.combine(base, "")
    local c = fs.combine(candidate, "")
    return string.sub(c, 1, #b) == b
end

local clientRequests = {}
local function allowRequest(id)
    if not id then return false end
    local now = os.time()
    clientRequests[id] = clientRequests[id] or {}
    local arr = clientRequests[id]
    local i = 1
    while i <= #arr do
        if now - arr[i] > SERVER_CONFIG.requestWindowSeconds then
            table.remove(arr, i)
        else i = i + 1 end
    end
    table.insert(arr, now)
    return #arr <= SERVER_CONFIG.maxRequestsPerWindow
end

local function cleanupClients()
    local now = os.time()
    for id, arr in pairs(clientRequests) do
        local keep = false
        for _, t in ipairs(arr) do if now - t <= SERVER_CONFIG.requestWindowSeconds then keep = true; break end end
        if not keep then clientRequests[id] = nil end
    end
end

local tasks = {}
local function addTask(task) table.insert(tasks, task) end
local function removeTaskAt(index) table.remove(tasks, index) end
local function countActiveDynamic()
    local n = 0
    for _, t in ipairs(tasks) do if t.status == "running" then n = n + 1 end end
    return n
end

local function runDynamicPage(path, timeoutSeconds, requestInfo)
    timeoutSeconds = timeoutSeconds or SERVER_CONFIG.defaultTimeoutSeconds
    local chunk, loadErr = loadfile(path)
    if not chunk then return false, "[Dynamic Page Error] " .. tostring(loadErr), 500 end

    local env = {print=print, pairs=pairs, ipairs=ipairs, type=type, tostring=tostring, tonumber=tonumber,
        os={time=os.time, clock=os.clock, date=os.date},
        string=string, table=table, math=math, fs=fs, shell=shell, http=http, peripheral=peripheral,
        rednet=rednet, sleep=sleep, theccwwwserver=theccwwwserver
    }

    if setfenv then pcall(setfenv, chunk, env)
    else
        local i = 1
        while true do
            local name = debug.getupvalue(chunk, i)
            if not name then break end
            if name == "_ENV" then debug.setupvalue(chunk, i, env); break end
            i = i + 1
        end
    end

    local co = coroutine.create(chunk)
    local startClock = os.clock()
    local function hook() if os.clock() - startClock > timeoutSeconds then error("Dynamic page timeout") end end

    if debug and debug.sethook then pcall(function() debug.sethook(co, hook, "", SERVER_CONFIG.hookInstructionCount) end) end

    local results, statusCode = nil, 200
    local success, res1 = pcall(function()
        local ok, r1 = coroutine.resume(co)
        while coroutine.status(co) ~= "dead" do ok, r1 = coroutine.resume(co) end
        results = {r1}
    end)

    if debug and debug.sethook then pcall(function() debug.sethook(co) end) end

    if not success then
        local errMsg = tostring(res1 or "Unknown error")
        statusCode = 500
        if string.find(errMsg, "timeout") then return false, "[Dynamic Page Timeout] " .. errMsg, statusCode
        else return false, "[Dynamic Page Error] " .. errMsg, statusCode end
    end

    local out = ""
    if results and #results > 0 and results[1] ~= nil then
        for i = 1, #results do if results[i] ~= nil then out = out .. tostring(results[i]) end end
    end

    return true, out, statusCode
end

local function sendResponse(clientId, responseContent, responseType, statusCode, redirect)
    statusCode = statusCode or 200
    local reason = httpStatus[statusCode] or "Unknown"
    local response
    if redirect then
        response = string.format(
            "THECCWEB/1 %d %s\r\nResponse-Type: %s\r\nLocation: %s\r\nContent-Length: 0\r\n\r\n",
            statusCode, reason, responseType or "Redirect", redirect
        )
    else
        response = string.format(
            "THECCWEB/1 %d %s\r\nResponse-Type: %s\r\nContent-Length: %d\r\n\r\n%s",
            statusCode, reason, responseType or "Page", #responseContent, responseContent or ""
        )
    end
    rednet.send(clientId, LibDeflate:CompressDeflate(response), "theccwww")
    theccwwwserver.log(string.format("[RESPONSE] To %s | Type: %s | Status: %d | Length: %d", clientId, responseType or "Page", statusCode, #responseContent))
end

local function serverLoop()
    theccwwwserver.log("Server loop starting...")
    local lastCleanupTick = os.clock()

    while true do
        local timeout = SERVER_CONFIG.schedulerTick
        local id, message = rednet.receive("theccwww", timeout)

        if os.time() - lastCleanupTick >= SERVER_CONFIG.cleanupInterval then
            cleanupClients()
            lastCleanupTick = os.time()
        end

        if id and message then
            if #message > SERVER_CONFIG.maxMessageBytes then
                local badResp = "THECCWEB/1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
                rednet.send(id, LibDeflate:CompressDeflate(badResp), "theccwww")
                theccwwwserver.log("[THROTTLE] Client " .. id .. " sent too large message.")
            else
                local ok, decompressed = pcall(function() return LibDeflate:DecompressDeflate(message) end)
                if not ok or not decompressed then
                    local badResp = "THECCWEB/1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
                    rednet.send(id, LibDeflate:CompressDeflate(badResp), "theccwww")
                    theccwwwserver.log("[ERROR] Client " .. id .. " sent invalid compressed message.")
                else
                    if not allowRequest(id) then
                        local resp = "THECCWEB/1 429 Too Many Requests\r\nContent-Length: 0\r\n\r\n"
                        rednet.send(id, LibDeflate:CompressDeflate(resp), "theccwww")
                        theccwwwserver.log(string.format("[THROTTLE] Client %s exceeded max requests (%d/%ds)", id, SERVER_CONFIG.maxRequestsPerWindow, SERVER_CONFIG.requestWindowSeconds))
                    else
                        local method, page, params, headers, body = parseRequest(decompressed)
                        theccwwwserver.method = method
                        theccwwwserver.path = "/" .. (page or "")
                        theccwwwserver.query = params
                        theccwwwserver.headers = headers
                        theccwwwserver.body = body or ""
                        theccwwwserver.statusCode = 200
                        theccwwwserver.redirect = nil

                        theccwwwserver.log(string.format("[REQUEST] From %s | Method: %s | Path: %s | Query: %s | Headers: %s",
                            id, method, theccwwwserver.path, textutils.serialize(params), textutils.serialize(headers)
                        ))

                        if not page or page == "" then page = "index" end
                        local candidates = {
                            page .. "." .. method .. ".dynamic.lua",
                            page .. "." .. method .. ".lua",
                            page .. ".dynamic.lua",
                            page .. ".lua",
                            page
                        }

                        local pathFound, responseContent, responseType, statusCode = nil, nil, nil, 200
                        for _, candidate in ipairs(candidates) do
                            local path = fs.combine(files, candidate)
                            if fs.exists(path) then
                                pathFound = path
                                if candidate:match("%.dynamic%.lua$") then responseType = "Dynamic"
                                elseif candidate:match("%.lua$") then responseType = "Page"
                                else responseType = "File" end
                                break
                            end
                        end

                        if not pathFound then
                            pathFound = fs.combine(files, "404.lua")
                            responseContent = safeReadFileCached(pathFound)
                            responseType = "Page"
                            statusCode = 404
                        else
                            if not isPathInside(files, pathFound) then
                                pathFound = fs.combine(files, "404.lua")
                                responseContent = safeReadFileCached(pathFound)
                                responseType = "Page"
                                statusCode = 403
                            elseif responseType == "Page" or responseType == "File" then
                                responseContent = safeReadFileCached(pathFound)
                                statusCode = 200
                            elseif responseType == "Dynamic" then
                                if countActiveDynamic() >= SERVER_CONFIG.maxConcurrentDynamic then
                                    responseContent = "[Server busy] Too many dynamic pages running."
                                    statusCode = 503
                                    sendResponse(id, responseContent, responseType, statusCode)
                                else
                                    local task = {
                                        id = id, path = pathFound, createdAt = os.time(),
                                        started = os.clock(), timeout = SERVER_CONFIG.defaultTimeoutSeconds,
                                        status = "queued", requestInfo = { method=method, page=page, params=params, headers=headers, body=body }
                                    }
                                    addTask(task)
                                    theccwwwserver.log(string.format("[DYNAMIC] Queued page: %s | Client: %s", pathFound, id))
                                end
                            end
                        end

                        if responseContent and statusCode then
                            sendResponse(id, responseContent, responseType, statusCode)
                        end
                    end
                end
            end
        end

        local processedThisTick, maxToProcess, i = 0, 2, 1
        while i <= #tasks and processedThisTick < maxToProcess do
            local t = tasks[i]
            if t.status == "queued" then
                t.status = "running"
                t.started = os.clock()
                theccwwwserver.log(string.format("[DYNAMIC] Running page: %s | Client: %s", t.path, t.id))
                local ok, result, sc = runDynamicPage(t.path, t.timeout, t.requestInfo)
                if not ok then
                    sc = sc or 500
                    sendResponse(t.id, result or "[Error]", "Dynamic", sc)
                    theccwwwserver.log(string.format("[DYNAMIC] Failed page: %s | Client: %s | StatusCode: %d", t.path, t.id, sc))
                    removeTaskAt(i)
                else
                    sendResponse(t.id, result or "", "Dynamic", 200)
                    theccwwwserver.log(string.format("[DYNAMIC] Finished page: %s | Client: %s", t.path, t.id))
                    removeTaskAt(i)
                end
                processedThisTick = processedThisTick + 1
            else
                removeTaskAt(i)
            end
        end
    end
end

serverLoop()
