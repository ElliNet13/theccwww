-- Start modems
peripheral.find("modem", rednet.open)

local destination = ...
if not destination then
    print("Enter the link to go to: ")
    destination = read()
end

-- Look up the destination
local domain, path = destination:match("^([^/]+)(/?.*)$")

if not domain then
    print("Invalid link")
    return
end

if not path then
    path = ""
end

-- Make theccwww
local theccwww = {}

-- Set the link
theccwww.link = {
    fulllink = destination,
    page = path,
    domain = domain
}

local server = nil
local sandbox = {}

-- Goto a page
function theccwww.gotopage(page)
    local x, y = term.getSize()
    print("Changing page to " .. (page or ("The homepage of" .. theccwww.link.domain)))
    theccwww.link.page = page or ""
    theccwww.link.fulllink = theccwww.link.domain .. "/" .. theccwww.link.page

    print("Sending message to " .. theccwww.link.domain)
    local gotSent = rednet.send(server, page or "", "theccwww")

    if not gotSent then
        error("Failed to send message to " .. theccwww.link.domain)
    end

    local id, message
    local maxWait = 5         -- seconds
    local elapsed = 0

    repeat
        -- Wait 1 second each loop
        id, message = rednet.receive("theccwww", 1)

        elapsed = elapsed + 1
        print("Loading page... will timeout in " .. (maxWait - elapsed) .. " seconds")

        if elapsed >= maxWait then
            error("Timeout: no response from server within " .. maxWait .. " seconds")
        end
    until id == server

    term.clear()
    term.setCursorPos(1, 1)
    load(message, "Website", "t", sandbox)()
end

-- Goto a site
function theccwww.gotosite(site, page)
    print("Changing site to " .. site)

    theccwww.link.domain = site
    theccwww.link.fulllink = site .. "/" .. (page or "")

    print("Looking up server for " .. site)
    -- Lookup server first
    server = rednet.lookup("theccwww", site)
    if not server then
        error("No server found for domain " .. site)
    end

    print("Sending message to " .. server)

    -- Send only the page path
    local gotSent = rednet.send(server, page or "")

    if not gotSent then
        error("Failed to send message to " .. site)
    end

    theccwww.gotopage(page or "")
end

-- Function to prompt yes/no 
function theccwww.promptYesNo(question)
    while true do
        write(question .. " (y/n): ")
        local answer = read()
        if answer then
            answer = answer:lower()
            if answer == "y" or answer == "yes" then
                return true
            elseif answer == "n" or answer == "no" then
                return false
            else
                print("Please enter 'y' or 'n'.")
            end
        end
    end
end

-- Get the contents of a file on a fileserver
function theccwww.download(domain, path)
    local fileserver = rednet.lookup("theccwww", domain)
    if not fileserver then
        error("No fileserver found for " .. domain)
    end

    -- Send a request to the server
    local gotSent = rednet.send(fileserver, path, "theccwww", 5)

    if not gotSent then
        error("Failed to send message to " .. domain)
    end

    local id, message = rednet.receive("theccwww")
    return message
end

-- Upload a file
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
        local file = fs.open(read(), mode)
        return file
    else
        print("Upload canceled.")
        os.sleep(1)
        return nil
    end
    
end

-- Require a link
function theccwww.require(domain, path)
    local fileserver = rednet.lookup("theccwww", domain)
    if not fileserver then
        error("No fileserver found for " .. domain)
    end

    -- Send a request to the server
    rednet.send(fileserver, path, "theccwww")

    -- Wait for a response, but with a timeout to prevent hanging forever
    local id, message = rednet.receive("theccwww", 5) -- 5-second timeout
    if not message then
        error("Timed out waiting for file from " .. domain .. "/" .. path)
    end

    -- Load the file in your sandbox
    return load(message, "Website require", "t", sandbox)()
end

-- Speakers
theccwww.speakers = { peripheral.find("speaker") }

-- Create a sandbox
sandbox = {
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
    server = server,
    theccwww = theccwww,
    term = term,
    rednet = {
        receive = rednet.receive,
        send = rednet.send,
        lookup = rednet.lookup
    },
    read = read,
    os = {
        clock = os.clock,
        time = os.time,
        date = os.date,
        pullEvent = os.pullEvent,
        sleep = os.sleep
    },
    xpcall = xpcall,
    pcall = pcall,
    require = function (path) -- A version for compatibility with built in require
        if path:match("^cc%.") then
            return require(path)
        else
            return theccwww.require(theccwww.link.domain, path)
        end
    end,
    colors = colors,
    colours = colours,
    load = load,
}

-- Go to the home page
theccwww.gotosite(theccwww.link.domain, theccwww.link.page)
