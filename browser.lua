-- Start modems
peripheral.find("modem", rednet.open)

-- Requirements
local LibDeflate = require("libraries.CC-Archive.LibDeflate")

local destination = ...
if not destination then
    write("Enter the link to go to: ")
    destination = read()
end

-- Parse domain and path
local domain, path = destination:match("^([^/]+)(/?.*)$")
if not domain then
    print("Invalid link")
    return
end
if not path then path = "" end

-- Browser object
local theccwww = {}
theccwww.link = {
    fulllink = destination,
    page = path,
    domain = domain
}

local server = nil

-- Fetch helper
theccwww.fetch = function(url, options)
    options = options or {}
    local method = (options.method or "GET"):upper()
    local headers = options.headers or {}
    local body = options.body or ""

    -- Parse domain/path
    local domain, path = url:match("^([^/]+)(/?.*)$")
    if not domain then error("Invalid URL: " .. tostring(url), 2) end
    if path == "" or path == "/" or path == nil then path = "index" end

    -- Lookup server
    local serverLookup = rednet.lookup("theccwww", domain)
    if not serverLookup then error("No server found for domain " .. domain, 2) end

    -- Build request
    local msg = string.format("%s /%s THECCWEB/1\r\n", method, path)
    for k,v in pairs(headers) do
        msg = msg .. string.format("%s: %s\r\n", k, v)
    end
    msg = msg .. "\r\n" .. body

    rednet.send(serverLookup, LibDeflate:CompressDeflate(msg), "theccwww")
    local _, response = rednet.receive("theccwww", 5)
    if not response then error("No response from server", 2) end

    response = LibDeflate:DecompressDeflate(response)

    if not response then error("Invalid response from server", 2) end

    -- Parse status line
    local statusLine = response:match("^(.-)\r?\n")
    local status = tonumber(statusLine:match("%d%d%d")) or 0

    -- Parse headers
    local respHeaders = {}
    for k, v in response:gmatch("([%w-]+):%s*(.-)\r?\n") do
        respHeaders[k:lower()] = v
    end

    -- Get body
    local respBody = response:match("\r?\n\r?\n(.*)$") or ""

    -- Handle redirect automatically
    if status == 302 and respHeaders["location"] then
        return theccwww.fetch(domain .. respHeaders["location"], options)
    end

    return {
        status = status,
        headers = respHeaders,
        body = respBody
    }
end

-- Sandbox environment for dynamic pages
local sandbox = {
    print = print,
    error = error,
    pairs = pairs,
    ipairs = ipairs,
    type = type,
    tonumber = tonumber,
    tostring = tostring,
    math = math,
    string = string,
    table = table,
    term = term,
    colors = colors,
    colours = colours,
    os = {
        clock = os.clock,
        time = os.time,
        date = os.date,
        pullEvent = os.pullEvent,
        sleep = os.sleep
    },
    read = read,
    xpcall = xpcall,
    pcall = pcall,
    load = load,
}

-- Add browser helpers and current request info
sandbox.theccwww = theccwww
sandbox.request = {
    method = "GET",
    path = theccwww.link.page,
    query = {},
    headers = {},
    body = "",
}

-- Go to a page
function theccwww.gotopage(page, method, body)
    if page == "" or page == "/" or page == nil then page = "index" end
    method = method or "GET"
    theccwww.link.page = page
    theccwww.link.fulllink = theccwww.link.domain .. "/" .. page:gsub("^/", "")

    if not server then
        server = rednet.lookup("theccwww", theccwww.link.domain)
        if not server then error("No server found for " .. theccwww.link.domain, 2) end
    end

    local response = theccwww.fetch(theccwww.link.domain .. "/" .. page, {method=method, body=body})

    -- Update sandbox request info
    sandbox.request.method = method
    sandbox.request.path = page
    sandbox.request.body = body
    sandbox.request.headers = response.headers

    -- Handle response types
    if response.headers["response-type"] == "File" then
        -- Auto-download file
        local filename = page:match("[^/]+$") or "downloaded_file"
        local f = fs.open(filename, "w")
        f.write(response.body)
        f.close()
        print("Downloaded file: " .. filename)
    elseif response.headers["response-type"] == "Page" or response.headers["response-type"] == "Dynamic" then
        -- Clear screen and execute dynamic/page content
        term.clear()
        term.setCursorPos(1,1)
        if response.body ~= "" then
            local fn, err = load(response.body, "Website", "t", sandbox)
            if fn then
                fn()
            else
                print("Error loading page: " .. err)
            end
        end
    else
        print("Unknown response type: " .. tostring(response.headers["response-type"]))
        print(response.body)
    end
end

-- Go to a site
function theccwww.gotosite(site, page)
    theccwww.link.domain = site
    theccwww.link.page = page or ""
    theccwww.link.fulllink = site .. "/" .. theccwww.link.page
    if not site then error("No site specified", 2) end
    server = rednet.lookup("theccwww", site)
    if not server then error("No server found for domain " .. site, 2) end
    theccwww.gotopage(theccwww.link.page)
end

-- File access
function theccwww.file(mode)
    print()
    print("The website requested to access a file")
    print("Wants to: " ..
    (mode == "r" and "read" or
     mode == "w" and "write" or
     mode == "a" and "append to" or
     mode == "x" and "create" or
     "unknown mode (" .. mode .. ")") .. " a file")

    if theccwww.promptYesNo("Are you sure you want to use this file?") then
        print("Where is the file?")
        return fs.open(read(), mode)
    else
        print("Upload canceled.")
        os.sleep(1)
        return nil
    end
end

-- Yes/no prompt
function theccwww.promptYesNo(question)
    while true do
        write(question .. " (y/n): ")
        local answer = read()
        if answer then
            answer = answer:lower()
            if answer == "y" or answer == "yes" then return true
            elseif answer == "n" or answer == "no" then return false
            else print("Please enter 'y' or 'n'.") end
        end
    end
end

-- Require a file dynamically
function theccwww.require(path, domain)
    if not domain then domain = theccwww.link.domain end
    if not path then error("No path specified", 2) end
    local internalRequirePaths = { "cc." }
    
    for _, v in pairs(internalRequirePaths) do
        if path:sub(1, #v) == v then
            return require(path)
        end
    end

    path = path:gsub("^/", "")

    local ok, response = pcall(theccwww.fetch, domain .. "/" .. path)
    if not ok then
        error("Require failed: " .. tostring(response), 2)
    end

    if response.status ~= 200 then
        error("Require failed: " .. domain .. "/" .. path .. " returned " .. tostring(response.status), 2)
    end

    local fn, err = load(response.body, "Website require: " .. path, "t", sandbox)
    if not fn then
        error("Require failed to load: " .. tostring(err), 2)
    end

    local ok2, result = pcall(fn)
    if not ok2 then
        error("Require failed to run: " .. tostring(result), 2)
    end

    return result
end

sandbox.require = theccwww.require

-- Speakers
theccwww.speakers = { peripheral.find("speaker") }

-- Start at home page
theccwww.gotosite(theccwww.link.domain, theccwww.link.page)
