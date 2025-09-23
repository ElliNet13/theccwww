-- Start modems
peripheral.find("modem", rednet.open)

print("Enter the link to go to: ")
local destination = read()

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
    print()
    term.setCursorPos(1, y)
    print("Site done (Execution finished): " .. theccwww.link.fulllink)
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

-- Save a file
function theccwww.save(domain, path)
    print()
    print("Requested to save: " .. domain .. "/" .. path)

    if theccwww.promptYesNo("Are you sure you want to save this file?") then
        print("Where do you want to save it?")
        local file = fs.open(read(), "w")
        local fileserver = rednet.lookup("theccwww", domain)
        local gotSent = rednet.send(fileserver, path, "theccwww")
        if not gotSent then
            error("Failed to send message to " .. domain)
        end
        print("Receiving file...")
        local id, message = rednet.receive("theccwww")
        print("Saving file...")
        file.write(message)
        file.close()
        print("File saved.")
        os.sleep(1)
    else
        print("Save canceled.")
        os.sleep(1)
    end
end

-- Require a link
function theccwww.require(domain, path)
    local fileserver = rednet.lookup("theccwww", domain)
    local gotSent = rednet.send(fileserver, path, "theccwww")
    if not gotSent then
        error("Failed to send message to " .. domain)
    end
    local id, message = rednet.receive("theccwww")
    return load(message, "Website require", "t", sandbox)()
end

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
        send = rednet.send
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
    require = function (path) -- A mini version for compatibility with built in require
        return theccwww.require(theccwww.link.domain, path)
    end
}

-- Go to the home page
theccwww.gotosite(theccwww.link.domain, theccwww.link.page)
