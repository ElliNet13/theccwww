---@diagnostic disable: duplicate-set-field

-- Requirements
local tinyyaml = require("libraries.tinyyaml")

-- Open the modem
peripheral.find("modem", rednet.open)

-- Load config
local dir = fs.getDir(shell.getRunningProgram())
local files = fs.combine(dir, "files")

if not fs.exists(dir .. "/config.yaml") then
    print("Creating config.yaml with default config")
    print("Make sure to change your hostname in the file!")
    fs.copy(dir .. "/server.default.yaml", dir .. "/config.yaml")
end

local file = fs.open(dir .. "/config.yaml", "r")
local config = tinyyaml.parse(file.readAll())
file.close()
local hostname = config.hostname

print("Starting server as " .. hostname)
print("Files: " .. files)

-- Ensure basic files exist
if not fs.exists(files) then fs.makeDir(files) end
if not fs.exists(files .. "/404.lua") then fs.copy(files .. "/404.default.lua", files .. "/404.lua") end
if not fs.exists(files .. "/index.lua") then fs.copy(files .. "/index.default.lua", files .. "/index.lua") end

-- Start hosting
rednet.host("theccwww", hostname)

-- Central API table for dynamic pages
theccwwwserver = {}
theccwwwserver.method = "GET"
theccwwwserver.path = "/"
theccwwwserver.query = {}
theccwwwserver.headers = {}
theccwwwserver.body = ""
theccwwwserver.statusCode = 200
theccwwwserver.redirect = nil
theccwwwserver.log = function(msg) print("[theccwww] " .. msg) end
theccwwwserver.uuid = function()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

-- Parse query string into table
local function parseQuery(query)
    local t = {}
    for k, v in string.gmatch(query, "([^&=]+)=([^&=]+)") do
        t[k] = v
    end
    return t
end

-- Parse headers into table
local function parseHeaders(headerString)
    local headers = {}
    for line in string.gmatch(headerString, "[^\r\n]+") do
        local k, v = string.match(line, "(.-):%s*(.*)")
        if k and v then headers[k:lower()] = v end
    end
    return headers
end

-- Safe file reading helper
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

-- Run dynamic page safely
local function runDynamicPage(path)
    theccwwwserver.statusCode = 200
    theccwwwserver.redirect = nil

    local fn, err = loadfile(path)
    if not fn then
        theccwwwserver.statusCode = 500
        return "[Dynamic Page Error] " .. err
    end
    local ok, result = pcall(fn)
    if not ok then
        theccwwwserver.statusCode = 500
        return "[Dynamic Page Error] " .. result
    end
    return result or ""
end

-- Parse request into method, path, query, headers, body
local function parseRequest(raw)
    local method, pathWithQuery, protocol = string.match(raw, "^(%S+)%s+(%S+)%s+(%S+)")
    if not method then
        method = "GET"
        pathWithQuery = raw
        protocol = "THECCWEB/1"
    end
    local page, query = string.match(pathWithQuery, "^/?([^?]+)%??(.*)")
    local params = query and parseQuery(query) or {}
    local headerString, body = string.match(raw, "^(.-)\r?\n\r?\n(.*)$")
    local headers = headerString and parseHeaders(headerString) or {}
    return method, page, params, headers, body or ""
end

-- HTTP status reason phrases
local httpStatus = {
    [200] = "OK",
    [201] = "Created",
    [302] = "Found",
    [400] = "Bad Request",
    [403] = "Forbidden",
    [404] = "Not Found",
    [500] = "Internal Server Error",
}

-- Main server loop
local function serverLoop()
    while true do
        local id, message = rednet.receive("theccwww")
        if not message or message == "" then message = "GET /index THECCWEB/1" end

        local method, page, params, headers, body = parseRequest(message)
        local responseType
        local responseContent
        local pathFound

        -- Populate theccwwwserver globals
        theccwwwserver.method = method
        theccwwwserver.path = "/" .. page
        theccwwwserver.query = params
        theccwwwserver.headers = headers
        theccwwwserver.body = body
        theccwwwserver.statusCode = 200
        theccwwwserver.redirect = nil

        -- Determine which file to serve
        if page == "" or page == "/" or page == nil then page = "index" end
        local candidates = {
            page .. "." .. method .. ".dynamic.lua",
            page .. "." .. method .. ".lua",
            page .. ".dynamic.lua",
            page .. ".lua",
            page
        }

        for _, candidate in ipairs(candidates) do
            local path = fs.combine(files, candidate)
            if fs.exists(path) then
                pathFound = path
                if candidate:match("%.dynamic%.lua$") then
                    responseContent = runDynamicPage(pathFound)
                    responseType = "Dynamic"
                elseif candidate:match("%.lua$") then
                    responseContent = safeReadFile(pathFound)
                    responseType = "Page"
                else
                    responseContent = safeReadFile(pathFound)
                    responseType = "File"
                end
                break
            end
        end

        -- Fallback 404
        if not pathFound then
            pathFound = fs.combine(files, "404.lua")
            responseContent = safeReadFile(pathFound)
            responseType = "Page"
            theccwwwserver.statusCode = 404
        end

        -- Directory traversal check
        if not string.find(pathFound, files .. "/", 1, true) then
            pathFound = fs.combine(files, "404.lua")
            responseContent = safeReadFile(pathFound)
            responseType = "Page"
            theccwwwserver.statusCode = 403
        end

        -- Determine HTTP status and reason
        local statusCode = theccwwwserver.redirect and 302 or theccwwwserver.statusCode
        local reason = httpStatus[statusCode] or "Unknown"

        -- Build response
        local response
        if theccwwwserver.redirect then
            response = string.format(
                "THECCWEB/1 %d %s\r\nResponse-Type: %s\r\nLocation: %s\r\nContent-Length: 0\r\n\r\n",
                statusCode, reason, responseType, theccwwwserver.redirect
            )
        else
            response = string.format(
                "THECCWEB/1 %d %s\r\nResponse-Type: %s\r\nContent-Length: %d\r\n\r\n%s",
                statusCode, reason, responseType, #responseContent, responseContent
            )
        end

        -- Send response
        rednet.send(id, response, "theccwww")
        print(string.format("[DONE] Sent %s (%s) to %s with status %d", pathFound, responseType, id, statusCode))
    end
end

serverLoop()
